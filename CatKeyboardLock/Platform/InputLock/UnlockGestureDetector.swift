import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum UnlockGestureDetection: Equatable {
    case none
    case holding(token: Int, shouldScheduleTimer: Bool)
    case unlock
}

struct UnlockGestureDetector {
    static let unlockKeyCode = Int64(kVK_ANSI_L)
    static let requiredFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

    let requiredHoldDuration: TimeInterval

    private var holdStart: TimeInterval?
    private var holdToken = 0

    init(requiredHoldDuration: TimeInterval = 1) {
        self.requiredHoldDuration = requiredHoldDuration
    }

    mutating func observe(
        eventType: CGEventType,
        keyCode: Int64,
        flags: CGEventFlags,
        timestamp: TimeInterval
    ) -> UnlockGestureDetection {
        guard eventType == .keyDown || eventType == .keyUp || eventType == .flagsChanged else {
            return .none
        }

        guard eventType == .keyDown else {
            if holdStart != nil {
                reset()
            }
            return .none
        }

        guard keyCode == Self.unlockKeyCode, Self.hasRequiredFlags(flags) else {
            if holdStart != nil {
                reset()
            }
            return .none
        }

        if let holdStart {
            if timestamp - holdStart >= requiredHoldDuration {
                reset()
                return .unlock
            }
            return .holding(token: holdToken, shouldScheduleTimer: false)
        }

        holdStart = timestamp
        holdToken += 1
        return .holding(token: holdToken, shouldScheduleTimer: true)
    }

    func isHolding(token: Int) -> Bool {
        holdStart != nil && holdToken == token
    }

    mutating func unlockIfStillHolding(token: Int) -> Bool {
        guard isHolding(token: token) else {
            return false
        }

        reset()
        return true
    }

    mutating func reset() {
        holdStart = nil
    }

    static func hasRequiredFlags(_ flags: CGEventFlags) -> Bool {
        let relevantFlags = flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift])
        return relevantFlags == requiredFlags
    }
}
