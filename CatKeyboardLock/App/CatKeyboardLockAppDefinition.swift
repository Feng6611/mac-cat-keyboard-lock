import Foundation
import KikiCommerceCore
import KikiRevenueCat

struct CatKeyboardLockAppDefinition {
    let config: CatKeyboardLockAppConfig
    let accessConfiguration: KikiAccessConfiguration
    let revenueCatConfiguration: RevenueCatConfiguration
    let launchOptions: CatKeyboardLockLaunchOptions

    let settingsAutosaveName: String
    let statusItemAutosaveName: String

    static func live(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Self {
        Self(
            config: .default,
            accessConfiguration: CatKeyboardLockRevenueCatConfiguration.accessConfiguration,
            revenueCatConfiguration: CatKeyboardLockRevenueCatConfiguration.revenueCatConfiguration,
            launchOptions: .current(arguments: arguments),
            settingsAutosaveName: "CatKeyboardLock.SettingsWindow",
            statusItemAutosaveName: "CatKeyboardLock.StatusItem"
        )
    }
}
