import AppKit
import KikiMenuBar

@MainActor
struct CatKeyboardLockMenuActions {
    let requestLock: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    init(
        requestLock: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.requestLock = requestLock
        self.openSettings = openSettings
        self.quit = quit
    }
}

enum CatKeyboardLockMenuModel {
    @MainActor
    static func items(
        config: CatKeyboardLockAppConfig,
        lockState: InputLockState,
        lockSettings: LockSettings,
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
            accessibilityTrusted: accessibilityTrusted,
            actions: actions
        ))
        items.append(.settings(title: "Settings…", action: actions.openSettings))

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
        accessibilityTrusted: Bool,
        actions: CatKeyboardLockMenuActions
    ) -> KikiMenuItem {
        let coreInput = CatKeyboardLockCoreInput(
            lockState: CatKeyboardLockCoreLockState(state),
            accessibilityTrusted: accessibilityTrusted
        )
        let evaluation = CatKeyboardLockCore.evaluate(coreInput)

        return .action(
            title: evaluation.menuLockTitle,
            action: actions.requestLock
        )
    }
}
