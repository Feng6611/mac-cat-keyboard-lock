import Foundation

enum CatKeyboardLockCoreLockState: String, Codable, Equatable {
    case unlocked
    case locked
}

enum CatKeyboardLockCoreAction: String, Codable, Equatable {
    case lock
    case unlock
    case openPermission
    case chooseInput
}

struct CatKeyboardLockCoreInput: Codable, Equatable {
    var lockState: CatKeyboardLockCoreLockState
    var accessibilityTrusted: Bool
    var lockKeyboard: Bool
    var lockMouseClicks: Bool

    init(
        lockState: CatKeyboardLockCoreLockState = .unlocked,
        accessibilityTrusted: Bool,
        lockKeyboard: Bool,
        lockMouseClicks: Bool
    ) {
        self.lockState = lockState
        self.accessibilityTrusted = accessibilityTrusted
        self.lockKeyboard = lockKeyboard
        self.lockMouseClicks = lockMouseClicks
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

        return hasPointerLock(input) ? "Lock Input" : "Lock Keyboard"
    }

    private static func lockRequestAction(for input: CatKeyboardLockCoreInput) -> CatKeyboardLockCoreAction {
        if input.lockState == .locked {
            return .unlock
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

        if !hasPolicy(input) {
            warnings.append("Choose at least one input type to lock.")
        }

        if hasPolicy(input) && !input.accessibilityTrusted {
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
