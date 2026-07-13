import CoreGraphics
import Foundation
import KikiCommerceCore
import KikiOnboarding
import KikiSettings

@MainActor
final class CatKeyboardLockAppComposition {
    let definition: CatKeyboardLockAppDefinition
    let lockSettings: LockSettings
    let inputLockController: InputLockController
    let accessManager: KikiAccessManager
    let onboardingState: CatKeyboardLockOnboardingState
    let settingsRoute: CatKeyboardLockSettingsRouteModel
    let settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>
    let onboardingCoordinator: KikiOnboardingCoordinator
    let router: CatKeyboardLockAppRouter
    let lifecycle: CatKeyboardLockLifecycleCoordinator

    init(
        definition: CatKeyboardLockAppDefinition = .live(),
        defaults: UserDefaults = .standard,
        commerceClient: (any CommerceClient)? = nil,
        permissionClient: InputLockPermissionClient = .live,
        presentPermissionHelp: (@MainActor () -> Void)? = nil,
        eventTapFactory: InputLockController.EventTapFactory? = nil
    ) {
        self.definition = definition

        let lockSettings = LockSettings(defaults: defaults)
        let inputLockController = InputLockController(
            settings: lockSettings,
            permissionClient: permissionClient,
            presentPermissionHelp: presentPermissionHelp,
            eventTapFactory: eventTapFactory
        )
        let accessManager: KikiAccessManager
        if let commerceClient {
            accessManager = KikiAccessManager(
                configuration: definition.accessConfiguration,
                defaults: defaults,
                commerceClient: commerceClient
            )
        } else {
            accessManager = KikiAccessManager(
                configuration: definition.accessConfiguration,
                revenueCatConfiguration: definition.revenueCatConfiguration,
                defaults: defaults
            )
        }
        let onboardingState = CatKeyboardLockOnboardingState(defaults: defaults)
        let settingsRoute = CatKeyboardLockSettingsRouteModel()
        let settingsCoordinator = KikiSettingsCoordinator(
            tabs: CatKeyboardLockSettingsTab.kikiTabs,
            initialTab: CatKeyboardLockSettingsTab.lock,
            windowController: KikiSettingsWindowController(
                frameAutosaveName: definition.settingsAutosaveName,
                minimumContentSize: CGSize(
                    width: KikiSettingsDefaults.minimumWindowWidth,
                    height: KikiSettingsDefaults.minimumWindowHeight
                )
            )
        )
        let onboardingCoordinator = CatKeyboardLockOnboardingFlow.makeCoordinator(
            config: definition.config,
            accessManager: accessManager,
            onboardingState: onboardingState,
            lockSettings: lockSettings,
            inputLockController: inputLockController,
            onFinish: {
                settingsCoordinator.select(.lock)
                settingsCoordinator.open()
            }
        )
        let router = CatKeyboardLockAppRouter(
            lockSettings: lockSettings,
            inputLockController: inputLockController,
            accessManager: accessManager,
            onboardingState: onboardingState,
            settingsRoute: settingsRoute,
            settingsCoordinator: settingsCoordinator,
            onboardingCoordinator: onboardingCoordinator
        )

        self.lockSettings = lockSettings
        self.inputLockController = inputLockController
        self.accessManager = accessManager
        self.onboardingState = onboardingState
        self.settingsRoute = settingsRoute
        self.settingsCoordinator = settingsCoordinator
        self.onboardingCoordinator = onboardingCoordinator
        self.router = router
        self.lifecycle = CatKeyboardLockLifecycleCoordinator(
            definition: definition,
            lockSettings: lockSettings,
            inputLockController: inputLockController,
            accessManager: accessManager,
            router: router
        )
    }
}
