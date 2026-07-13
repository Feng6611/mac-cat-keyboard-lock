import AppKit
import KikiCommerceCore
import KikiOnboarding
import KikiSettings

@MainActor
final class CatKeyboardLockAppRouter {
    private(set) var lastPerformedLockAction: CatKeyboardLockCoreAction?
    private let lockSettings: LockSettings
    private let inputLockController: InputLockController
    private let accessManager: KikiAccessManager
    private let onboardingState: CatKeyboardLockOnboardingState
    private let settingsRoute: CatKeyboardLockSettingsRouteModel
    private let settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>
    private let onboardingCoordinator: KikiOnboardingCoordinator
    private let quitApplication: () -> Void

    init(
        lockSettings: LockSettings,
        inputLockController: InputLockController,
        accessManager: KikiAccessManager,
        onboardingState: CatKeyboardLockOnboardingState,
        settingsRoute: CatKeyboardLockSettingsRouteModel,
        settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>,
        onboardingCoordinator: KikiOnboardingCoordinator,
        quitApplication: (() -> Void)? = nil
    ) {
        self.lockSettings = lockSettings
        self.inputLockController = inputLockController
        self.accessManager = accessManager
        self.onboardingState = onboardingState
        self.settingsRoute = settingsRoute
        self.settingsCoordinator = settingsCoordinator
        self.onboardingCoordinator = onboardingCoordinator
        self.quitApplication = quitApplication ?? { NSApp.terminate(nil) }
    }

    var lockEvaluation: CatKeyboardLockCoreEvaluation {
        CatKeyboardLockCore.evaluate(
            CatKeyboardLockCoreInput(
                access: CatKeyboardLockCoreAccess(status: accessManager.status),
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
        initialTab: CatKeyboardLockInitialSettingsTab? = nil,
        presentsPaywall: Bool = false
    ) {
        if let initialTab {
            settingsCoordinator.select(initialTab.settingsTab)
        }

        if presentsPaywall {
            settingsCoordinator.select(.about)
            settingsRoute.isPaywallSheetPresented = true
        }

        settingsCoordinator.open()
    }

    func openPaywall() {
        openSettings(initialTab: .about, presentsPaywall: true)
    }

    func presentLaunchScene(_ scene: CatKeyboardLockLaunchScene, settingsTab: CatKeyboardLockInitialSettingsTab?) {
        switch scene {
        case .onboarding:
            onboardingCoordinator.start()
        case .settings:
            openSettings(initialTab: settingsTab)
        case .paywall:
            openPaywall()
        }
    }

    func showAutomaticOnboardingIfAllowed() {
        guard accessManager.readiness.allowsAutomaticPresentation else {
            return
        }
        showOnboardingIfNeeded()
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
        case .openPaywall:
            openPaywall()
        case .openPermission:
            inputLockController.requestPermissions()
        case .chooseInput:
            openSettings(initialTab: .lock)
        }
    }

    private func showOnboardingIfNeeded() {
        guard onboardingState.shouldShow(
            isPro: accessManager.status.isPro,
            hasAccessOverride: hasDebugAccessOverride
        ) else {
            return
        }

        onboardingCoordinator.start()
    }

    private var hasDebugAccessOverride: Bool {
#if DEBUG
        accessManager.debugProAccessOverride != nil
#else
        false
#endif
    }
}

extension CatKeyboardLockCoreAccess {
    init(status: KikiAccessState) {
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

extension CatKeyboardLockCoreLockState {
    init(_ state: InputLockState) {
        self = state.isLocked ? .locked : .unlocked
    }
}
