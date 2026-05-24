import AppKit
import KikiMenuBar

@MainActor
struct CatKeyboardLockMenuActions {
    let lock: () -> Void
    let unlock: () -> Void
    let openSettings: () -> Void
    let openPaywall: () -> Void
    let toggleDebugProAccess: () -> Void
    let clearDebugProAccessOverride: () -> Void
    let quit: () -> Void

    init(
        lock: @escaping () -> Void,
        unlock: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        openPaywall: @escaping () -> Void,
        toggleDebugProAccess: @escaping () -> Void = {},
        clearDebugProAccessOverride: @escaping () -> Void = {},
        quit: @escaping () -> Void
    ) {
        self.lock = lock
        self.unlock = unlock
        self.openSettings = openSettings
        self.openPaywall = openPaywall
        self.toggleDebugProAccess = toggleDebugProAccess
        self.clearDebugProAccessOverride = clearDebugProAccessOverride
        self.quit = quit
    }
}

enum CatKeyboardLockMenuModel {
    private static let lockShortcut = KikiMenuShortcut(
        key: "l",
        modifiers: [.control, .option, .command]
    )

    @MainActor
    static func items(
        config: CatKeyboardLockAppConfig,
        lockState: InputLockState,
        lockSettings: LockSettings,
        entitlement: CatKeyboardLockEntitlementSnapshot,
        actions: CatKeyboardLockMenuActions
    ) -> [KikiMenuItem] {
        var items: [KikiMenuItem] = [
            .status(title: lockState.menuStatusText(lockDurationInterval: lockSettings.lockDurationInterval)),
        ]

        if lockState.isLocked {
            items.append(.status(title: "Hold ⌃⌥⌘L for 1s to unlock"))
        }

        items.append(.separator)
        items.append(lockAction(
            for: lockState,
            lockSettings: lockSettings,
            entitlement: entitlement,
            actions: actions
        ))
        items.append(.settings(title: "Settings...", action: actions.openSettings))

        if !entitlement.isPro {
            items.append(.action(
                title: "Upgrade to Pro...",
                isEnabled: true,
                action: actions.openPaywall
            ))
        }

#if DEBUG
        items.append(.separator)
        items.append(.toggle(
            title: "Test Paid Access",
            isOn: entitlement.isPro,
            isEnabled: true,
            action: actions.toggleDebugProAccess
        ))

        items.append(.action(
            title: "Clear Test Override",
            isEnabled: true,
            action: actions.clearDebugProAccessOverride
        ))
#endif

        items.append(contentsOf: [
            .separator,
            .quit(
                appName: config.appName,
                action: actions.quit
            )
        ])

        return items
    }

    @MainActor
    private static func lockAction(
        for state: InputLockState,
        lockSettings: LockSettings,
        entitlement: CatKeyboardLockEntitlementSnapshot,
        actions: CatKeyboardLockMenuActions
    ) -> KikiMenuItem {
        let coreInput = CatKeyboardLockCoreInput(
            access: CatKeyboardLockCoreAccess(status: entitlement.status),
            lockState: CatKeyboardLockCoreLockState(state),
            accessibilityTrusted: true,
            lockKeyboard: lockSettings.lockKeyboard,
            lockMouseClicks: lockSettings.lockMouseClicks,
            lockPointerMovement: lockSettings.lockPointerMovement
        )
        let evaluation = CatKeyboardLockCore.evaluate(coreInput)

        if state.isLocked {
            return .action(
                title: evaluation.menuLockTitle,
                shortcut: lockShortcut,
                action: actions.unlock
            )
        }

        guard entitlement.isAccessActive else {
            return .action(
                title: evaluation.menuLockTitle,
                shortcut: lockShortcut,
                action: actions.openPaywall
            )
        }

        return .action(
            title: evaluation.menuLockTitle,
            shortcut: lockShortcut,
            action: actions.lock
        )
    }
}

private extension CatKeyboardLockCoreAccess {
    init(status: CatKeyboardLockProStatus) {
        switch status {
        case .notStarted:
            self = .notStarted
        case .trial:
            self = .trial
        case .expired:
            self = .expired
        case .pro:
            self = .pro
        }
    }
}

private extension CatKeyboardLockCoreLockState {
    init(_ state: InputLockState) {
        self = state.isLocked ? .locked : .unlocked
    }
}
