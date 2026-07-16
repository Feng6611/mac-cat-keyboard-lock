import AppKit
import KikiCommerceCore
import KikiMenuBar

@MainActor
struct CatKeyboardLockMenuActions {
    let requestLock: () -> Void
    let openSettings: () -> Void
    let openPaywall: () -> Void
    let toggleDebugProAccess: () -> Void
    let clearDebugProAccessOverride: () -> Void
    let quit: () -> Void

    init(
        requestLock: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        openPaywall: @escaping () -> Void,
        toggleDebugProAccess: @escaping () -> Void = {},
        clearDebugProAccessOverride: @escaping () -> Void = {},
        quit: @escaping () -> Void
    ) {
        self.requestLock = requestLock
        self.openSettings = openSettings
        self.openPaywall = openPaywall
        self.toggleDebugProAccess = toggleDebugProAccess
        self.clearDebugProAccessOverride = clearDebugProAccessOverride
        self.quit = quit
    }
}

enum CatKeyboardLockMenuModel {
    @MainActor
    static func items(
        config: CatKeyboardLockAppConfig,
        lockState: InputLockState,
        lockSettings: LockSettings,
        entitlement: CatKeyboardLockEntitlementSnapshot,
        accessibilityTrusted: Bool,
        actions: CatKeyboardLockMenuActions
    ) -> [KikiMenuItem] {
        var items: [KikiMenuItem] = [
            .status(title: lockState.menuStatusText(lockDurationInterval: lockSettings.lockDurationInterval)),
        ]

        items.append(.separator)
        items.append(lockAction(
            for: lockState,
            lockSettings: lockSettings,
            entitlement: entitlement,
            accessibilityTrusted: accessibilityTrusted,
            actions: actions
        ))
        items.append(.settings(title: "Settings…", action: actions.openSettings))

        if !entitlement.isPro && entitlement.isAccessActive {
            items.append(.action(
                title: "Upgrade to Pro…",
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
        accessibilityTrusted: Bool,
        actions: CatKeyboardLockMenuActions
    ) -> KikiMenuItem {
        let coreInput = CatKeyboardLockCoreInput(
            access: CatKeyboardLockCoreAccess(status: entitlement.status),
            lockState: CatKeyboardLockCoreLockState(state),
            accessibilityTrusted: accessibilityTrusted,
            lockKeyboard: lockSettings.lockKeyboard,
            lockMouseClicks: lockSettings.lockMouseClicks
        )
        let evaluation = CatKeyboardLockCore.evaluate(coreInput)

        return .action(
            title: evaluation.menuLockTitle,
            action: actions.requestLock
        )
    }
}
