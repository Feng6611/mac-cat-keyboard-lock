import Foundation

enum InputLockState: Equatable {
    case unlocked
    case locked(startedAt: Date)
    case permissionRequired(reason: String)
    case failed(reason: String)

    var isLocked: Bool {
        if case .locked = self {
            return true
        }
        return false
    }

    var statusText: String {
        switch self {
        case .unlocked:
            return "Ready to lock"
        case .locked:
            return "Locked"
        case .permissionRequired:
            return "Permission required"
        case .failed:
            return "Lock failed"
        }
    }

    func menuStatusText(lockDurationInterval: TimeInterval) -> String {
        switch self {
        case .unlocked:
            return "Ready to lock"
        case .locked(let startedAt):
            let elapsed = Date().timeIntervalSince(startedAt)
            let remaining = max(0, lockDurationInterval - elapsed)
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            return "Locked — \(minutes):\(String(format: "%02d", seconds)) remaining"
        case .permissionRequired:
            return "Permission required"
        case .failed(let reason):
            return reason
        }
    }

    var detailText: String {
        switch self {
        case .unlocked:
            return "Your keyboard is active."
        case .locked:
            return "Input blocked until unlock or timeout."
        case .permissionRequired(let reason),
             .failed(let reason):
            return reason
        }
    }
}

enum InputLockUnlockReason: Equatable {
    case manual
    case triggerCorner
    case timeout
    case tapDisabled
    case appTerminated
}
