import CoreGraphics
import Foundation
import KikiOnboarding
import KikiSettings

@MainActor
final class CatKeyboardLockAppComposition {
    let definition: CatKeyboardLockAppDefinition
    let lockSettings: LockSettings
    let inputLockController: InputLockController
    let onboardingState: CatKeyboardLockOnboardingState
    let supportState: CatKeyboardLockSupportState
    let settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>
    let onboardingCoordinator: KikiOnboardingCoordinator
    let router: CatKeyboardLockAppRouter
    let lifecycle: CatKeyboardLockLifecycleCoordinator

    init(
        definition: CatKeyboardLockAppDefinition = .live(),
        defaults: UserDefaults = .standard,
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
        let onboardingState = CatKeyboardLockOnboardingState(defaults: defaults)
        let supportState = CatKeyboardLockSupportState(defaults: defaults)
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
            onboardingState: onboardingState,
            settingsCoordinator: settingsCoordinator,
            onboardingCoordinator: onboardingCoordinator
        )

        self.lockSettings = lockSettings
        self.inputLockController = inputLockController
        self.onboardingState = onboardingState
        self.supportState = supportState
        self.settingsCoordinator = settingsCoordinator
        self.onboardingCoordinator = onboardingCoordinator
        self.router = router
        self.lifecycle = CatKeyboardLockLifecycleCoordinator(
            definition: definition,
            lockSettings: lockSettings,
            inputLockController: inputLockController,
            supportState: supportState,
            router: router
        )
    }
}
