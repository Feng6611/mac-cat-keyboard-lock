import CoreGraphics
import Foundation

protocol InputLockEventTapping: AnyObject {
    var isStarted: Bool { get }
    func start() -> Bool
    func stop()
}

final class InputLockEventTap: InputLockEventTapping {
    typealias UnlockHandler = () -> Void
    typealias DisabledHandler = (String) -> Void

    private let policy: InputLockPolicy
    private let onFallbackUnlock: UnlockHandler
    private let onTapDisabled: DisabledHandler
    private var unlockDetector = UnlockGestureDetector()
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let eventTap = Unmanaged<InputLockEventTap>.fromOpaque(userInfo).takeUnretainedValue()
        return eventTap.handle(eventType: type, event: event)
    }

    init(
        policy: InputLockPolicy,
        onFallbackUnlock: @escaping UnlockHandler,
        onTapDisabled: @escaping DisabledHandler
    ) {
        self.policy = policy
        self.onFallbackUnlock = onFallbackUnlock
        self.onTapDisabled = onTapDisabled
    }

    deinit {
        stop()
    }

    var isStarted: Bool {
        machPort != nil
    }

    func start() -> Bool {
        guard !policy.isEmpty else {
            return false
        }

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: policy.eventMask,
            callback: Self.callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        machPort = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let machPort {
            CGEvent.tapEnable(tap: machPort, enable: false)
            CFMachPortInvalidate(machPort)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        machPort = nil
        unlockDetector.reset()
    }

    private func handle(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            onTapDisabled("macOS stopped the keyboard lock. Try locking again.")
            return Unmanaged.passUnretained(event)
        }

        if handleFallbackUnlock(eventType: eventType, event: event) {
            return nil
        }

        if policy.shouldSuppress(eventType) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleFallbackUnlock(eventType: CGEventType, event: CGEvent) -> Bool {
        let detection = unlockDetector.observe(
            eventType: eventType,
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            flags: event.flags,
            timestamp: TimeInterval(event.timestamp) / 1_000_000_000
        )

        switch detection {
        case .none:
            return false
        case .holding(let token, let shouldScheduleTimer):
            if shouldScheduleTimer {
                scheduleUnlockTimer(token: token)
            }
            return true
        case .unlock:
            onFallbackUnlock()
            return true
        }
    }

    private func scheduleUnlockTimer(token: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + unlockDetector.requiredHoldDuration) { [weak self] in
            guard let self, self.unlockDetector.unlockIfStillHolding(token: token) else {
                return
            }

            self.onFallbackUnlock()
        }
    }
}
