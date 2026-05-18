import ApplicationServices
import CoreGraphics
import Foundation
import OSLog

struct InputLockPermissionClient {
    let isAccessibilityTrusted: (_ prompt: Bool) -> Bool

    static let live = InputLockPermissionClient(
        isAccessibilityTrusted: { prompt in
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
    )
}

struct InputLockPermissionStatus: Equatable {
    let accessibilityTrusted: Bool

    static let unknown = InputLockPermissionStatus(
        accessibilityTrusted: false
    )

    var accessibilityText: String {
        accessibilityTrusted ? "Allowed" : "Needs permission"
    }

    var missingPermissionReason: String {
        accessibilityTrusted
            ? "macOS refused the input filter. Try quitting and reopening the app."
            : "Cat Keyboard Lock needs Accessibility to block input."
    }
}

@MainActor
final class InputLockController: ObservableObject {
    typealias EventTapFactory = (
        _ policy: InputLockPolicy,
        _ onFallbackUnlock: @escaping () -> Void,
        _ onTapDisabled: @escaping (String) -> Void
    ) -> InputLockEventTapping

    @Published private(set) var state: InputLockState = .unlocked
    @Published private(set) var lastUnlockReason: InputLockUnlockReason?
    @Published private(set) var permissionStatus: InputLockPermissionStatus = .unknown

    private let settings: LockSettings
    private let permissionClient: InputLockPermissionClient
    private let eventTapFactory: EventTapFactory
    private var eventTap: InputLockEventTapping?
    private var timeoutTimer: Timer?
    private let logger = Logger(subsystem: "dev.kkuk.catkeyboardlock", category: "InputLock")
    private static let accessibilityRequiredReason = "Cat Keyboard Lock needs Accessibility to block input."

    init(
        settings: LockSettings,
        permissionClient: InputLockPermissionClient = .live,
        eventTapFactory: @escaping EventTapFactory = { policy, onFallbackUnlock, onTapDisabled in
            InputLockEventTap(
                policy: policy,
                onFallbackUnlock: onFallbackUnlock,
                onTapDisabled: onTapDisabled
            )
        }
    ) {
        self.settings = settings
        self.permissionClient = permissionClient
        self.eventTapFactory = eventTapFactory
    }

    deinit {
        timeoutTimer?.invalidate()
        eventTap?.stop()
    }

    func lock(now: Date = Date()) {
        guard !state.isLocked else {
            return
        }

        let policy = settings.policy
        guard !policy.isEmpty else {
            state = .failed(reason: "Choose at least one input type to lock.")
            return
        }

        let permissionStatus = checkPermissions(promptAccessibility: true)
        logger.info(
            "Lock requested. accessibility=\(permissionStatus.accessibilityTrusted), mask=\(policy.eventMask)"
        )

        guard permissionStatus.accessibilityTrusted else {
            state = .permissionRequired(
                reason: Self.accessibilityRequiredReason
            )
            return
        }

        let tap = eventTapFactory(
            policy,
            { [weak self] in
                Task { @MainActor in
                    self?.unlock(reason: .fallbackShortcut)
                }
            },
            { [weak self] reason in
                Task { @MainActor in
                    self?.handleTapDisabled(reason: reason)
                }
            }
        )

        guard tap.start() else {
            tap.stop()
            let updatedStatus = checkPermissions(promptAccessibility: false)
            logger.error(
                "Event tap failed to start. accessibility=\(updatedStatus.accessibilityTrusted)"
            )
            if updatedStatus.accessibilityTrusted {
                state = .failed(reason: updatedStatus.missingPermissionReason)
            } else {
                state = .permissionRequired(reason: updatedStatus.missingPermissionReason)
            }
            return
        }

        eventTap = tap
        state = .locked(startedAt: now)
        logger.info("Input lock started.")
        lastUnlockReason = nil
        scheduleTimeout()
    }

    func unlock(reason: InputLockUnlockReason = .manual) {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        eventTap?.stop()
        eventTap = nil
        logger.info("Input lock stopped. reason=\(String(describing: reason))")
        lastUnlockReason = reason
        state = .unlocked
    }

    func toggle() {
        if state.isLocked {
            unlock(reason: .manual)
        } else {
            lock()
        }
    }

    func refreshPermissions() {
        guard !state.isLocked else {
            return
        }

        let status = checkPermissions(promptAccessibility: false)
        if status.accessibilityTrusted {
            if case .permissionRequired(let reason) = state,
               reason == Self.accessibilityRequiredReason {
                state = .unlocked
            }
        } else if case .permissionRequired = state {
            state = .permissionRequired(
                reason: Self.accessibilityRequiredReason
            )
        }
    }

    func requestPermissions() {
        let status = checkPermissions(promptAccessibility: true)
        if !status.accessibilityTrusted {
            state = .permissionRequired(reason: Self.accessibilityRequiredReason)
        } else if case .permissionRequired(let reason) = state,
                  reason == Self.accessibilityRequiredReason {
            state = .unlocked
        }
        refreshPermissions()
    }

    private func checkPermissions(promptAccessibility: Bool) -> InputLockPermissionStatus {
        let accessibilityTrusted = permissionClient.isAccessibilityTrusted(promptAccessibility)
        let status = InputLockPermissionStatus(
            accessibilityTrusted: accessibilityTrusted
        )
        permissionStatus = status
        return status
    }

    private func scheduleTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: settings.lockDurationInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.unlock(reason: .timeout)
            }
        }
    }

    private func handleTapDisabled(reason: String) {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        eventTap?.stop()
        eventTap = nil
        lastUnlockReason = .tapDisabled
        logger.error("Input lock tap disabled. reason=\(reason)")
        state = .failed(reason: reason)
    }

    #if DEBUG
    func expireLockForTesting() {
        unlock(reason: .timeout)
    }
    #endif
}
