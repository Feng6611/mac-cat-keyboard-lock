import Foundation

enum CatKeyboardLockCoreAccess: String, CaseIterable, Codable, Equatable {
    case notStarted
    case trial
    case expired
    case pro

    var isActive: Bool {
        switch self {
        case .trial, .pro:
            return true
        case .notStarted, .expired:
            return false
        }
    }

    var canStartTrial: Bool {
        self == .notStarted
    }

    var displayName: String {
        switch self {
        case .notStarted:
            return "Trial not started"
        case .trial:
            return "Trial active"
        case .expired:
            return "Trial ended"
        case .pro:
            return "Pro"
        }
    }
}

enum CatKeyboardLockCoreLockState: String, Codable, Equatable {
    case unlocked
    case locked
}

enum CatKeyboardLockCoreAction: String, Codable, Equatable {
    case lock
    case unlock
    case openPaywall
    case openPermission
    case chooseInput
}

struct CatKeyboardLockCoreInput: Codable, Equatable {
    var access: CatKeyboardLockCoreAccess
    var lockState: CatKeyboardLockCoreLockState
    var accessibilityTrusted: Bool
    var lockKeyboard: Bool
    var lockMouseClicks: Bool

    init(
        access: CatKeyboardLockCoreAccess,
        lockState: CatKeyboardLockCoreLockState = .unlocked,
        accessibilityTrusted: Bool,
        lockKeyboard: Bool,
        lockMouseClicks: Bool
    ) {
        self.access = access
        self.lockState = lockState
        self.accessibilityTrusted = accessibilityTrusted
        self.lockKeyboard = lockKeyboard
        self.lockMouseClicks = lockMouseClicks
    }
}

struct CatKeyboardLockCoreEvaluation: Codable, Equatable {
    let statusText: String
    let accessText: String
    let permissionText: String
    let menuLockTitle: String
    let lockRequestAction: CatKeyboardLockCoreAction
    let policySummary: [String]
    let warnings: [String]
}

enum CatKeyboardLockCore {
    static func evaluate(_ input: CatKeyboardLockCoreInput) -> CatKeyboardLockCoreEvaluation {
        let policySummary = policySummary(for: input)
        let lockRequestAction = lockRequestAction(for: input)
        let warnings = warnings(for: input)

        return CatKeyboardLockCoreEvaluation(
            statusText: statusText(for: input, action: lockRequestAction),
            accessText: input.access.displayName,
            permissionText: input.accessibilityTrusted ? "Allowed" : "Needs permission",
            menuLockTitle: menuLockTitle(for: input),
            lockRequestAction: lockRequestAction,
            policySummary: policySummary,
            warnings: warnings
        )
    }

    private static func menuLockTitle(for input: CatKeyboardLockCoreInput) -> String {
        if input.lockState == .locked {
            return "Unlock"
        }

        guard input.access.isActive else {
            return input.access.canStartTrial ? "Start Free Trial…" : "Upgrade to Lock…"
        }

        return hasPointerLock(input) ? "Lock Input" : "Lock Keyboard"
    }

    private static func lockRequestAction(for input: CatKeyboardLockCoreInput) -> CatKeyboardLockCoreAction {
        if input.lockState == .locked {
            return .unlock
        }

        guard input.access.isActive else {
            return .openPaywall
        }

        guard hasPolicy(input) else {
            return .chooseInput
        }

        guard input.accessibilityTrusted else {
            return .openPermission
        }

        return .lock
    }

    private static func statusText(
        for input: CatKeyboardLockCoreInput,
        action: CatKeyboardLockCoreAction
    ) -> String {
        switch action {
        case .unlock:
            return "Locked"
        case .openPaywall:
            return input.access.displayName
        case .chooseInput:
            return "Choose input to lock"
        case .openPermission:
            return "Needs Accessibility"
        case .lock:
            return "Ready to lock"
        }
    }

    private static func policySummary(for input: CatKeyboardLockCoreInput) -> [String] {
        var summary: [String] = []

        if input.lockKeyboard {
            summary.append("keyboard")
        }

        if input.lockMouseClicks {
            summary.append("clicks")
        }

        return summary
    }

    private static func warnings(for input: CatKeyboardLockCoreInput) -> [String] {
        var warnings: [String] = []

        if !input.access.isActive {
            warnings.append("Access is not active.")
        }

        if !hasPolicy(input) {
            warnings.append("Choose at least one input type to lock.")
        }

        if input.access.isActive && hasPolicy(input) && !input.accessibilityTrusted {
            warnings.append("Accessibility is required before input can be locked.")
        }

        return warnings
    }

    private static func hasPolicy(_ input: CatKeyboardLockCoreInput) -> Bool {
        input.lockKeyboard || input.lockMouseClicks
    }

    private static func hasPointerLock(_ input: CatKeyboardLockCoreInput) -> Bool {
        input.lockMouseClicks
    }
}
