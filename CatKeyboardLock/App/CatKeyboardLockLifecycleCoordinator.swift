import AppKit
import Combine
import KikiCommerceCore
import KikiMenuBar
import KikiOverlay
import KikiTriggerCorner

@MainActor
final class CatKeyboardLockLifecycleCoordinator {
    private let definition: CatKeyboardLockAppDefinition
    private let lockSettings: LockSettings
    private let inputLockController: InputLockController
    private let accessManager: KikiAccessManager
    private let router: CatKeyboardLockAppRouter

    private lazy var screenEdgeOverlayController = KikiScreenEdgeOverlayController(
        style: CatKeyboardLockOverlayPresentations.style(for: lockSettings)
    )
    private lazy var triggerCornerMonitor = KikiTriggerCornerMonitor(
        configurationProvider: { [weak self] in
            self?.lockSettings.triggerCornerConfiguration ?? .disabled
        },
        onTrigger: { [weak self] in
            self?.router.toggleFromTriggerCorner()
        }
    )
    private var menuBarController: KikiMenuBarController?
    private var cancellables: Set<AnyCancellable> = []
    private var lastObservedLockState: InputLockState?
    private var lastTriggerCornerLockState = false
    private var didStart = false

    init(
        definition: CatKeyboardLockAppDefinition,
        lockSettings: LockSettings,
        inputLockController: InputLockController,
        accessManager: KikiAccessManager,
        router: CatKeyboardLockAppRouter
    ) {
        self.definition = definition
        self.lockSettings = lockSettings
        self.inputLockController = inputLockController
        self.accessManager = accessManager
        self.router = router
    }

    func start() {
        guard !didStart else {
            return
        }
        didStart = true

        NSApp.setActivationPolicy(.accessory)
        menuBarController = KikiMenuBarController(
            title: definition.config.statusItemTitle,
            autosaveName: definition.statusItemAutosaveName,
            systemImageName: "cat",
            accessibilityDescription: definition.config.appName,
            tooltip: definition.config.appName,
            itemsProvider: { [weak self] in
                self?.menuItems() ?? []
            }
        )
        bindRuntimeState()
        inputLockController.refreshPermissions()
        updateTriggerCornerMonitor()
        routeStartup()
    }

    func stop() {
        triggerCornerMonitor.stop()
        inputLockController.unlock(reason: .appTerminated)
        screenEdgeOverlayController.hideImmediately()
        cancellables.removeAll()
    }

    private func routeStartup() {
        if let scene = definition.launchOptions.scene {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self else { return }
                self.router.presentLaunchScene(scene, settingsTab: self.definition.launchOptions.settingsTab)
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.accessManager.refresh()
            self.updateTriggerCornerMonitor()
            if self.definition.launchOptions.scene == nil {
                self.router.showAutomaticOnboardingIfAllowed()
            }
        }
    }

    private func menuItems() -> [KikiMenuItem] {
        inputLockController.refreshPermissions()
        return CatKeyboardLockMenuModel.items(
            config: definition.config,
            lockState: inputLockController.state,
            lockSettings: lockSettings,
            entitlement: CatKeyboardLockEntitlementSnapshot(status: accessManager.status),
            accessibilityTrusted: inputLockController.permissionStatus.accessibilityTrusted,
            actions: CatKeyboardLockMenuActions(
                requestLock: { [weak self] in self?.router.requestLockAction() },
                openSettings: { [weak self] in self?.router.openSettings() },
                openPaywall: { [weak self] in self?.router.openPaywall() },
                toggleDebugProAccess: { [weak self] in
#if DEBUG
                    guard let self else { return }
                    if self.accessManager.debugProAccessOverride == .pro {
                        self.accessManager.clearDebugProAccessOverride()
                    } else {
                        self.accessManager.setDebugProAccessOverride(.pro)
                    }
#endif
                },
                clearDebugProAccessOverride: { [weak self] in
#if DEBUG
                    self?.accessManager.clearDebugProAccessOverride()
#endif
                },
                quit: { [weak self] in self?.router.quit() }
            )
        )
    }

    private func bindRuntimeState() {
        inputLockController.$state
            .sink { [weak self] state in
                self?.updateStatusItem(for: state)
                self?.showEdgeHighlightIfNeeded(for: state)
                self?.updateTriggerCornerMonitor()
            }
            .store(in: &cancellables)

        lockSettings.$overlayEffectLevel
            .dropFirst()
            .debounce(for: .milliseconds(180), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateOverlayStyle(showPreview: !self.inputLockController.state.isLocked)
            }
            .store(in: &cancellables)

        lockSettings.$triggerCornerEnabled
            .dropFirst()
            .sink { [weak self] _ in self?.updateTriggerCornerMonitor() }
            .store(in: &cancellables)

        accessManager.$status
            .dropFirst()
            .sink { [weak self] _ in self?.updateTriggerCornerMonitor() }
            .store(in: &cancellables)
    }

    private func updateTriggerCornerMonitor() {
        let isLocked = inputLockController.state.isLocked
        if isLocked != lastTriggerCornerLockState {
            triggerCornerMonitor.disarmUntilExit()
            lastTriggerCornerLockState = isLocked
        }

        if lockSettings.triggerCornerEnabled && (accessManager.status.isActive || isLocked) {
            triggerCornerMonitor.start()
        } else {
            triggerCornerMonitor.stop()
        }
    }

    private func updateOverlayStyle(showPreview: Bool) {
        screenEdgeOverlayController.updateStyle(
            CatKeyboardLockOverlayPresentations.style(for: lockSettings)
        )
        if showPreview {
            screenEdgeOverlayController.show(CatKeyboardLockOverlayPresentations.settingsPreview())
        }
    }

    private func showEdgeHighlightIfNeeded(for state: InputLockState) {
        defer { lastObservedLockState = state }
        guard let previousState = lastObservedLockState else { return }

        switch (previousState.isLocked, state.isLocked) {
        case (false, true):
            screenEdgeOverlayController.show(CatKeyboardLockOverlayPresentations.lockStarted())
        case (true, false):
            switch state {
            case .unlocked where inputLockController.lastUnlockReason != .appTerminated:
                screenEdgeOverlayController.show(
                    CatKeyboardLockOverlayPresentations.lockEnded(reason: inputLockController.lastUnlockReason)
                )
            case .permissionRequired(let reason), .failed(let reason):
                screenEdgeOverlayController.show(CatKeyboardLockOverlayPresentations.warning(reason: reason))
            default:
                break
            }
        case (false, false):
            if case .permissionRequired(let reason) = state {
                screenEdgeOverlayController.show(CatKeyboardLockOverlayPresentations.warning(reason: reason))
            } else if case .failed(let reason) = state {
                screenEdgeOverlayController.show(CatKeyboardLockOverlayPresentations.warning(reason: reason))
            }
        default:
            break
        }
    }

    private func updateStatusItem(for state: InputLockState) {
        let description = statusItemDescription(for: state)
        menuBarController?.updateButtonImage(
            systemImageName: "cat",
            accessibilityDescription: description
        )
        menuBarController?.updateButtonState(isActive: state.isLocked)
        menuBarController?.updateButtonTint(statusItemTint(for: state))
        menuBarController?.updateButtonTooltip(description)
    }

    private func statusItemTint(for state: InputLockState) -> NSColor? {
        switch state {
        case .unlocked: return nil
        case .locked, .permissionRequired: return .systemOrange
        case .failed: return .systemRed
        }
    }

    private func statusItemDescription(for state: InputLockState) -> String {
        let suffix: String
        switch state {
        case .unlocked: suffix = "unlocked"
        case .locked: suffix = "locked"
        case .permissionRequired: suffix = "permission required"
        case .failed: suffix = "lock failed"
        }
        return "\(definition.config.appName): \(suffix)"
    }
}
