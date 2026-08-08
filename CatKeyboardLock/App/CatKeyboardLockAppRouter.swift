import AppKit
import KikiOnboarding
import KikiSettings

@MainActor
final class CatKeyboardLockAppRouter {
    private(set) var lastPerformedLockAction: CatKeyboardLockCoreAction?
    private let lockSettings: LockSettings
    private let inputLockController: InputLockController
    private let onboardingState: CatKeyboardLockOnboardingState
    private let settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>
    private let onboardingCoordinator: KikiOnboardingCoordinator
    private let quitApplication: () -> Void

    init(
        lockSettings: LockSettings,
        inputLockController: InputLockController,
        onboardingState: CatKeyboardLockOnboardingState,
        settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>,
        onboardingCoordinator: KikiOnboardingCoordinator,
        quitApplication: (() -> Void)? = nil
    ) {
        self.lockSettings = lockSettings
        self.inputLockController = inputLockController
        self.onboardingState = onboardingState
        self.settingsCoordinator = settingsCoordinator
        self.onboardingCoordinator = onboardingCoordinator
        self.quitApplication = quitApplication ?? { NSApp.terminate(nil) }
    }

    var lockEvaluation: CatKeyboardLockCoreEvaluation {
        CatKeyboardLockCore.evaluate(
            CatKeyboardLockCoreInput(
                lockState: CatKeyboardLockCoreLockState(inputLockController.state),
                accessibilityTrusted: inputLockController.permissionStatus.accessibilityTrusted,
                lockKeyboard: lockSettings.lockKeyboard,
                lockMouseClicks: lockSettings.lockMouseClicks
            )
        )
    }

    func requestLockAction() {
        if !inputLockController.state.isLocked {
            inputLockController.refreshPermissions()
        }

        perform(lockEvaluation.lockRequestAction)
    }

    func toggleFromTriggerCorner() {
        requestLockAction()
    }

    func openSettings(
        initialTab: CatKeyboardLockInitialSettingsTab? = nil
    ) {
        if let initialTab {
            settingsCoordinator.select(initialTab.settingsTab)
        }

        settingsCoordinator.open()
    }

    func presentLaunchScene(_ scene: CatKeyboardLockLaunchScene, settingsTab: CatKeyboardLockInitialSettingsTab?) {
        switch scene {
        case .onboarding:
            onboardingCoordinator.start()
        case .settings:
            openSettings(initialTab: settingsTab)
        }
    }

    func showOnboardingIfNeeded() {
        guard onboardingState.shouldShow() else {
            return
        }

        onboardingCoordinator.start()
    }

    func triggerOnboarding() {
        onboardingState.reset()
        onboardingCoordinator.resetCompletion()
        onboardingCoordinator.start()
    }

    func quit() {
        quitApplication()
    }

    private func perform(_ action: CatKeyboardLockCoreAction) {
        lastPerformedLockAction = action
        switch action {
        case .lock:
            inputLockController.lock()
        case .unlock:
            inputLockController.unlock(reason: .manual)
        case .openPermission:
            inputLockController.requestPermissions()
        case .chooseInput:
            openSettings(initialTab: .lock)
        }
    }
}

extension CatKeyboardLockCoreLockState {
    init(_ state: InputLockState) {
        self = state.isLocked ? .locked : .unlocked
    }
}
