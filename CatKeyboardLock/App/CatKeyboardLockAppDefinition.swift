import Foundation

struct CatKeyboardLockAppDefinition {
    let config: CatKeyboardLockAppConfig
    let launchOptions: CatKeyboardLockLaunchOptions

    let settingsAutosaveName: String
    let statusItemAutosaveName: String

    static func live(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Self {
        Self(
            config: .default,
            launchOptions: .current(arguments: arguments),
            settingsAutosaveName: "CatKeyboardLock.SettingsWindow",
            statusItemAutosaveName: "CatKeyboardLock.StatusItem"
        )
    }
}
