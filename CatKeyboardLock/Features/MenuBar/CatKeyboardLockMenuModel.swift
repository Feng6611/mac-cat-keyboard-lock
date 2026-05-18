import AppKit
import KikiMenuBar

@MainActor
struct CatKeyboardLockMenuActions {
    let lock: () -> Void
    let unlock: () -> Void
    let openSettings: () -> Void
    let openPaywall: () -> Void
    let quit: () -> Void
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
        if state.isLocked {
            return .action(
                title: "Unlock",
                shortcut: lockShortcut,
                action: actions.unlock
            )
        }

        guard entitlement.isAccessActive else {
            return .action(
                title: entitlement.canStartTrial ? "Start Trial / Upgrade..." : "Upgrade to Lock...",
                shortcut: lockShortcut,
                action: actions.openPaywall
            )
        }

        let title = lockSettings.hasPointerLock ? "Lock Input" : "Lock Keyboard"
        return .action(
            title: title,
            shortcut: lockShortcut,
            action: actions.lock
        )
    }
}
