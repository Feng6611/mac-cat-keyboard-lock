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
                initialTab: appDelegate.launchOptions.settingsTab ?? .lock,
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
    let launchOptions = CatKeyboardLockLaunchOptions.current()

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
        inputLockController: inputLockController,
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
        if launchOptions.scene == .onboarding {
            onboardingWindowController.show()
        } else {
            onboardingWindowController.showIfNeeded()
        }
        Task { @MainActor [weak self] in
            await self?.proStatusManager.refresh()
            self?.updateTriggerCornerMonitor()
        }
        presentLaunchSceneIfNeeded()
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
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .accessory {
            NSApp.setActivationPolicy(.regular)
        }

        settingsOpener.open()

        if previousPolicy == .accessory {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    func openPaywall() {
        paywallWindowController.show()
    }

    private func presentLaunchSceneIfNeeded() {
        guard let scene = launchOptions.scene else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else {
                return
            }

            switch scene {
            case .onboarding:
                self.onboardingWindowController.show()
            case .settings:
                self.openSettings()
            case .paywall:
                self.openPaywall()
            }
        }
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

enum CatKeyboardLockLaunchScene: Equatable {
    case onboarding
    case settings
    case paywall
}

struct CatKeyboardLockLaunchOptions: Equatable {
    let scene: CatKeyboardLockLaunchScene?
    let settingsTab: CatKeyboardLockInitialSettingsTab?

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self {
        var scene: CatKeyboardLockLaunchScene?
        var settingsTab: CatKeyboardLockInitialSettingsTab?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "--ui-smoke-onboarding":
                scene = .onboarding
            case "--ui-smoke-paywall":
                scene = .paywall
            case "--ui-smoke-settings":
                scene = .settings
                if index + 1 < arguments.count,
                   let tab = CatKeyboardLockInitialSettingsTab(rawValue: arguments[index + 1]) {
                    settingsTab = tab
                    index += 1
                }
            default:
                if argument.hasPrefix("--ui-smoke-settings=") {
                    scene = .settings
                    let rawTab = String(argument.dropFirst("--ui-smoke-settings=".count))
                    settingsTab = CatKeyboardLockInitialSettingsTab(rawValue: rawTab)
                }
            }

            index += 1
        }

        return Self(scene: scene, settingsTab: settingsTab)
    }
}
