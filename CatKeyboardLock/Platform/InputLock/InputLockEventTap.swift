import CoreGraphics
import Foundation

protocol InputLockEventTapping: AnyObject {
    var isStarted: Bool { get }
    func start() -> Bool
    func stop()
}

final class InputLockEventTap: InputLockEventTapping {
    typealias DisabledHandler = (String) -> Void

    private let policy: InputLockPolicy
    private let onTapDisabled: DisabledHandler
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
        onTapDisabled: @escaping DisabledHandler
    ) {
        self.policy = policy
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
    }

    private func handle(eventType: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            onTapDisabled("macOS stopped the keyboard lock. Try locking again.")
            return Unmanaged.passUnretained(event)
        }

        if policy.shouldSuppress(eventType) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
