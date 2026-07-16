import CoreGraphics
import Foundation
import KikiAuthorization
import OSLog

struct InputLockPermissionClient {
    let isAccessibilityTrusted: @MainActor (_ prompt: Bool) -> Bool

    static let live = InputLockPermissionClient(
        isAccessibilityTrusted: { prompt in
            if prompt {
                return KikiAuthorizationPanel.accessibility.requestSystemPrompt()
            }

            return KikiAuthorizationPanel.accessibility.isAuthorized
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
    static let onboardingPracticeTimeout: TimeInterval = 60

    typealias EventTapFactory = (
        _ policy: InputLockPolicy,
        _ onTapDisabled: @escaping (String) -> Void
    ) -> InputLockEventTapping

    @Published private(set) var state: InputLockState = .unlocked
    @Published private(set) var lastUnlockReason: InputLockUnlockReason?
    @Published private(set) var permissionStatus: InputLockPermissionStatus = .unknown

    private let settings: LockSettings
    private let permissionClient: InputLockPermissionClient
    private let presentPermissionHelp: @MainActor () -> Void
    private let eventTapFactory: EventTapFactory
    private var eventTap: InputLockEventTapping?
    private var timeoutTimer: Timer?
    private let logger = Logger(subsystem: "dev.kkuk.catkeyboardlock", category: "InputLock")
    private static let accessibilityRequiredReason = "Cat Keyboard Lock needs Accessibility to block input."

    static let presentLivePermissionHelp: @MainActor () -> Void = {
        KikiAuthorizationAssistant.shared.present(
            panel: .accessibility,
            instruction: "Turn on Cat Keyboard Lock in Accessibility so it can block input while locked."
        )
    }

    init(
        settings: LockSettings,
        permissionClient: InputLockPermissionClient = .live,
        presentPermissionHelp: (@MainActor () -> Void)? = nil,
        eventTapFactory: EventTapFactory? = nil
    ) {
        self.settings = settings
        self.permissionClient = permissionClient
        self.presentPermissionHelp = presentPermissionHelp ?? Self.presentLivePermissionHelp
        self.eventTapFactory = eventTapFactory ?? { policy, onTapDisabled in
            InputLockEventTap(
                policy: policy,
                onTapDisabled: onTapDisabled
            )
        }
    }

    deinit {
        timeoutTimer?.invalidate()
        eventTap?.stop()
    }

    func lock(now: Date = Date()) {
        startLock(
            policy: settings.policy,
            now: now,
            timeoutInterval: settings.lockDurationInterval
        )
    }

    func lockForOnboardingPractice(now: Date = Date()) {
        startLock(
            policy: InputLockPolicy(lockKeyboard: true, lockMouseClicks: false),
            now: now,
            timeoutInterval: Self.onboardingPracticeTimeout
        )
    }

    private func startLock(
        policy: InputLockPolicy,
        now: Date,
        timeoutInterval: TimeInterval
    ) {
        guard !state.isLocked else {
            return
        }

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
        scheduleTimeout(after: timeoutInterval)
    }

    func unlock(reason: InputLockUnlockReason = .manual) {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        eventTap?.stop()
        eventTap = nil
        lastUnlockReason = reason
        logger.info("Input lock stopped. reason=\(String(describing: reason))")
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
            presentPermissionHelp()
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

    private func scheduleTimeout(after interval: TimeInterval) {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
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
