import AppKit
import Combine
import KikiMenuBar
import KikiOverlay
import KikiSettings
import KikiTriggerCorner
import SwiftUI

@main
struct CatKeyboardLockApp: App {
    @NSApplicationDelegateAdaptor(CatKeyboardLockAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            CatKeyboardLockSettingsView(
                config: appDelegate.config,
                lockSettings: appDelegate.lockSettings,
                inputLockController: appDelegate.inputLockController,
                proStatusManager: appDelegate.proStatusManager,
                openPaywall: { appDelegate.openPaywall() }
            )
        }
    }
}

@MainActor
final class CatKeyboardLockAppDelegate: NSObject, NSApplicationDelegate {
    let config = CatKeyboardLockAppConfig.default
    let lockSettings = LockSettings()
    lazy var inputLockController = InputLockController(settings: lockSettings)
    let proStatusManager = CatKeyboardLockProStatusManager()

    private let settingsWindowController = KikiSettingsWindowController(
        frameAutosaveName: "CatKeyboardLock.SettingsWindow",
        minimumContentSize: CGSize(
            width: KikiSettingsDefaults.minimumWindowWidth,
            height: KikiSettingsDefaults.minimumWindowHeight
        ),
        windowTitle: "Settings"
    )
    private lazy var settingsOpener = KikiSettingsOpener(windowController: settingsWindowController)
    private lazy var paywallWindowController = CatKeyboardLockPaywallWindowController(
        config: config,
        proStatusManager: proStatusManager
    )
    private lazy var onboardingWindowController = CatKeyboardLockOnboardingWindowController(
        proStatusManager: proStatusManager,
        onFinish: { [weak self] in
            self?.updateTriggerCornerMonitor()
        }
    )
    private lazy var screenEdgeOverlayController = KikiScreenEdgeOverlayController(
        style: CatKeyboardLockOverlayPresentations.style(for: lockSettings)
    )
    private lazy var triggerCornerMonitor = KikiTriggerCornerMonitor(
        configurationProvider: { [weak self] in
            guard let self else {
                return .disabled
            }

            return self.lockSettings.triggerCornerConfiguration
        },
        onTrigger: { [weak self] in
            self?.toggleFromTriggerCorner()
        }
    )
    private var menuBarController: KikiMenuBarController?
    private var cancellables: Set<AnyCancellable> = []
    private var lastObservedLockState: InputLockState?
    private var lastTriggerCornerLockState = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = KikiMenuBarController(
            title: config.statusItemTitle,
            autosaveName: "CatKeyboardLock.StatusItem",
            systemImageName: "keyboard",
            accessibilityDescription: config.appName,
            tooltip: config.appName,
            itemsProvider: { [weak self] in
                self?.menuItems() ?? []
            }
        )
        bindLockStateToStatusItem()
        inputLockController.refreshPermissions()
        proStatusManager.configureIfNeeded()
        updateTriggerCornerMonitor()
        onboardingWindowController.showIfNeeded()
        Task { @MainActor [weak self] in
            await self?.proStatusManager.refresh()
            self?.updateTriggerCornerMonitor()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        triggerCornerMonitor.stop()
        inputLockController.unlock(reason: .appTerminated)
        screenEdgeOverlayController.hideImmediately()
    }

    private func menuItems() -> [KikiMenuItem] {
        CatKeyboardLockMenuModel.items(
            config: config,
            lockState: inputLockController.state,
            lockSettings: lockSettings,
            entitlement: proStatusManager.snapshot,
            actions: CatKeyboardLockMenuActions(
                lock: { [weak self] in self?.lockIfAllowed() },
                unlock: { [weak self] in self?.inputLockController.unlock(reason: .manual) },
                openSettings: { [weak self] in self?.openSettings() },
                openPaywall: { [weak self] in self?.openPaywall() },
                toggleDebugProAccess: { [weak self] in
#if DEBUG
                    self?.proStatusManager.toggleDebugProAccessOverride()
#endif
                },
                clearDebugProAccessOverride: { [weak self] in
#if DEBUG
                    self?.proStatusManager.clearDebugProAccessOverride()
#endif
                },
                quit: { NSApp.terminate(nil) }
            )
        )
    }

    private func lockIfAllowed() {
        guard proStatusManager.status.isActive else {
            openPaywall()
            return
        }

        inputLockController.lock()
    }

    private func toggleFromTriggerCorner() {
        if inputLockController.state.isLocked {
            inputLockController.unlock(reason: .triggerCorner)
        } else {
            lockIfAllowed()
        }
    }

    private func openSettings() {
        settingsOpener.open()
    }

    func openPaywall() {
        paywallWindowController.show()
    }

    private func bindLockStateToStatusItem() {
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
                guard let self else {
                    return
                }
                self.updateOverlayStyle(showPreview: !self.inputLockController.state.isLocked)
            }
            .store(in: &cancellables)

        lockSettings.$triggerCornerEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateTriggerCornerMonitor()
            }
            .store(in: &cancellables)

        proStatusManager.$status
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateTriggerCornerMonitor()
            }
            .store(in: &cancellables)
    }

    private func updateTriggerCornerMonitor() {
        let isLocked = inputLockController.state.isLocked
        if isLocked != lastTriggerCornerLockState {
            triggerCornerMonitor.disarmUntilExit()
            lastTriggerCornerLockState = isLocked
        }

        if lockSettings.triggerCornerEnabled && (proStatusManager.status.isActive || isLocked) {
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
            screenEdgeOverlayController.show(
                CatKeyboardLockOverlayPresentations.settingsPreview()
            )
        }
    }

    private func showEdgeHighlightIfNeeded(for state: InputLockState) {
        defer { lastObservedLockState = state }
        guard let previousState = lastObservedLockState else {
            return
        }

        switch (previousState.isLocked, state.isLocked) {
        case (false, true):
            screenEdgeOverlayController.show(CatKeyboardLockOverlayPresentations.lockStarted())
        case (true, false):
            switch state {
            case .unlocked where inputLockController.lastUnlockReason != .appTerminated:
                screenEdgeOverlayController.show(
                    CatKeyboardLockOverlayPresentations.lockEnded(reason: inputLockController.lastUnlockReason)
                )
            case .permissionRequired(let reason),
                 .failed(let reason):
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
        menuBarController?.updateButtonImage(
            systemImageName: "keyboard",
            accessibilityDescription: statusItemDescription(for: state)
        )
        menuBarController?.updateButtonState(isActive: state.isLocked)
        menuBarController?.updateButtonTint(statusItemTint(for: state))
        menuBarController?.updateButtonTooltip(statusItemDescription(for: state))
    }

    private func statusItemTint(for state: InputLockState) -> NSColor? {
        switch state {
        case .unlocked:
            return nil
        case .locked:
            return .systemOrange
        case .permissionRequired:
            return .systemOrange
        case .failed:
            return .systemRed
        }
    }

    private func statusItemDescription(for state: InputLockState) -> String {
        switch state {
        case .unlocked:
            return "\(config.appName): unlocked"
        case .locked:
            return "\(config.appName): locked"
        case .permissionRequired:
            return "\(config.appName): permission required"
        case .failed:
            return "\(config.appName): lock failed"
        }
    }
}
