import Foundation
import KikiSettings
import KikiTriggerCorner
import SwiftUI

enum CatKeyboardLockSettingsTab: String, CaseIterable, Identifiable {
    case lock
    case system
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lock:
            return "Lock"
        case .system:
            return "System"
        case .about:
            return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .lock:
            return "lock"
        case .system:
            return "gearshape"
        case .about:
            return "info.circle"
        }
    }

    static var kikiTabs: [KikiSettingsTabSpec<CatKeyboardLockSettingsTab>] {
        allCases.map { tab in
            KikiSettingsTabSpec(tab, title: tab.title, systemImage: tab.systemImage)
        }
    }
}

enum CatKeyboardLockInitialSettingsTab: String {
    case lock
    case system
    case about

    var settingsTab: CatKeyboardLockSettingsTab {
        switch self {
        case .lock:
            return .lock
        case .system:
            return .system
        case .about:
            return .about
        }
    }
}

@MainActor
final class CatKeyboardLockSettingsNavigationModel: ObservableObject {
    static let shared = CatKeyboardLockSettingsNavigationModel()

    @Published var selectedTab: CatKeyboardLockSettingsTab
    @Published var isPaywallSheetPresented = false

    init(selectedTab: CatKeyboardLockSettingsTab = .lock) {
        self.selectedTab = selectedTab
    }
}

struct CatKeyboardLockSettingsView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var lockSettings: LockSettings
    @ObservedObject var inputLockController: InputLockController
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager
    @StateObject private var navigation: CatKeyboardLockSettingsNavigationModel

    init(
        config: CatKeyboardLockAppConfig,
        lockSettings: LockSettings,
        inputLockController: InputLockController,
        proStatusManager: CatKeyboardLockProStatusManager,
        navigationModel: CatKeyboardLockSettingsNavigationModel = .shared,
        initialTab: CatKeyboardLockInitialSettingsTab = .lock
    ) {
        self.config = config
        self.lockSettings = lockSettings
        self.inputLockController = inputLockController
        self.proStatusManager = proStatusManager
        if initialTab != .lock {
            navigationModel.selectedTab = initialTab.settingsTab
        }
        _navigation = StateObject(
            wrappedValue: navigationModel
        )
    }

    var body: some View {
        KikiSettingsShell(
            selection: $navigation.selectedTab,
            tabs: CatKeyboardLockSettingsTab.kikiTabs
        ) { tab in
            switch tab {
            case .lock:
                lockPane
            case .system:
                systemPane
            case .about:
                aboutPane
            }
        }
        .sheet(isPresented: $navigation.isPaywallSheetPresented) {
            CatKeyboardLockPaywallSheetView(
                config: config,
                proStatusManager: proStatusManager,
                context: .settings
            )
        }
    }

    private var lockPane: some View {
        KikiSettingsPane {
            Section {
                KikiSettingsToggleRow("Keyboard", isOn: $lockSettings.lockKeyboard, systemImage: "keyboard")
                KikiSettingsToggleRow("Clicks", isOn: $lockSettings.lockMouseClicks)
            } footer: {
                KikiSettingsHelperText(
                    "Keyboard is the core lock. Clicks are an optional extension."
                )
            }

            Section {
                KikiSettingsValueRow("Lock / unlock shortcut") {
                    Text("⌃⌥⌘L (hold 1s)")
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
                lockDurationRow
                lockFeedbackRow
            } header: {
                Text("Shortcut & Safety")
            } footer: {
                KikiSettingsHelperText(
                    "Use the shortcut or menu bar item to switch lock state. The app also releases the lock after the selected duration."
                )
            }

            Section {
                KikiSettingsToggleRow("Trigger corner", isOn: $lockSettings.triggerCornerEnabled, systemImage: "cursorarrow")
                triggerCornerRow
                    .disabled(!lockSettings.triggerCornerEnabled)
            } header: {
                Text("Trigger Corner")
            } footer: {
                KikiSettingsHelperText(
                    "Move the pointer into the selected corner and hold briefly to lock or unlock. This uses pointer position polling and does not add another permission."
                )
            }
        }
    }

#if DEBUG
    private var debugTestingSection: some View {
        Section {
            KikiSettingsStatusRow(
                title: "Test override",
                value: proStatusManager.debugProAccessOverrideDisplayName,
                systemImage: "hammer",
                valueColor: proStatusManager.debugProAccessOverride == nil ? .secondary : .orange
            )

            KikiSettingsToggleRow("Paid access", isOn: debugProAccessBinding, systemImage: "sparkles")

            Button("Clear Test Override") {
                proStatusManager.clearDebugProAccessOverride()
            }
            .disabled(proStatusManager.debugProAccessOverride == nil)
        } header: {
            Text("Developer Testing")
        } footer: {
            KikiSettingsHelperText("Debug builds only. Forces the local Pro gate without making or restoring a purchase.")
        }
    }

    private var debugProAccessBinding: Binding<Bool> {
        Binding(
            get: { proStatusManager.debugProAccessToggleIsOn },
            set: { proStatusManager.setDebugProAccessOverride($0) }
        )
    }
#endif

    private var systemPane: some View {
        KikiSettingsPane {
            Section {
                LaunchAtLogin.Toggle("Launch at Login")
                KikiAuthorizationStatusRow(
                    title: "Accessibility",
                    isAuthorized: inputLockController.permissionStatus.accessibilityTrusted,
                    unauthorizedValue: inputLockController.permissionStatus.accessibilityText,
                    action: inputLockController.requestPermissions
                )
            } footer: {
                KikiSettingsHelperText("Accessibility is required to block input while locked.")
            }
        }
    }

    private var lockDurationRow: some View {
        KikiSettingsSegmentedPickerRow(
            "Lock duration",
            selection: $lockSettings.lockDurationMinutes,
            options: LockSettings.lockDurationOptions,
            controlWidth: 250,
            optionTitle: { "\($0) min" }
        )
    }

    private var lockFeedbackRow: some View {
        KikiSettingsSegmentedPickerRow(
            "Lock feedback",
            selection: $lockSettings.overlayEffectLevel,
            options: LockSettings.overlayEffectLevels,
            controlWidth: 150,
            leadingCaption: "Subtle",
            trailingCaption: "Strong",
            optionTitle: { "\($0)" }
        )
    }

    private var triggerCornerRow: some View {
        KikiSettingsSegmentedPickerRow(
            "Corner",
            selection: $lockSettings.triggerCorner,
            options: KikiTriggerCorner.allCases,
            controlWidth: 320,
            optionTitle: { $0.title }
        )
    }

    private var aboutPane: some View {
        KikiSettingsPane {
            Section {
                KikiAppIdentityView(
                    appName: config.appName,
                    versionText: versionText
                )
                .padding(.vertical, 20)
            }

            Section {
                KikiSettingsStatusRow(
                    title: "Status",
                    value: proStatusManager.status.displayName,
                    systemImage: "checkmark.seal",
                    valueColor: proStatusManager.status.isActive ? Color(red: 0.58, green: 0.20, blue: 0.62) : .orange,
                    trailingSystemImage: aboutStatusTrailingSystemImage,
                    action: aboutStatusAction
                )
            }

            Section {
                KikiSettingsLinkRow(
                    title: "Official",
                    value: config.officialDisplayName,
                    urlString: config.officialURL,
                    systemImage: "globe"
                )
                KikiSettingsCopyRow(
                    title: "Email",
                    value: config.contactEmailAddress,
                    systemImage: "envelope"
                )
                KikiSettingsLinkRow(
                    title: "GitHub",
                    value: config.repositoryDisplayName,
                    urlString: config.repositoryURL,
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )
            }

#if DEBUG
            debugTestingSection
#endif
        }
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private var aboutStatusTrailingSystemImage: String? {
        "chevron.right"
    }

    private var aboutStatusAction: (() -> Void)? {
        {
            navigation.isPaywallSheetPresented = true
        }
    }

}
