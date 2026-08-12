import Foundation

enum CatKeyboardLockCoreLockState: String, Codable, Equatable {
    case unlocked
    case locked
}

enum CatKeyboardLockCoreAction: String, Codable, Equatable {
    case lock
    case unlock
    case openPermission
}

struct CatKeyboardLockCoreInput: Codable, Equatable {
    var lockState: CatKeyboardLockCoreLockState
    var accessibilityTrusted: Bool

    init(
        lockState: CatKeyboardLockCoreLockState = .unlocked,
        accessibilityTrusted: Bool
    ) {
        self.lockState = lockState
        self.accessibilityTrusted = accessibilityTrusted
    }
}

struct CatKeyboardLockCoreEvaluation: Codable, Equatable {
    let statusText: String
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

        return "Lock Keyboard"
    }

    private static func lockRequestAction(for input: CatKeyboardLockCoreInput) -> CatKeyboardLockCoreAction {
        if input.lockState == .locked {
            return .unlock
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
        case .openPermission:
            return "Needs Accessibility"
        case .lock:
            return "Ready to lock"
        }
    }

    private static func policySummary(for input: CatKeyboardLockCoreInput) -> [String] {
        ["keyboard"]
    }

    private static func warnings(for input: CatKeyboardLockCoreInput) -> [String] {
        var warnings: [String] = []

        if !input.accessibilityTrusted {
            warnings.append("Accessibility is required before input can be locked.")
        }

        return warnings
    }

}
