import Foundation
import KikiCommerceCore
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
final class CatKeyboardLockSettingsRouteModel: ObservableObject {
    @Published var isPaywallSheetPresented = false
}

enum CatKeyboardLockSettingsTint {
    static let brand = Color(red: 0.58, green: 0.20, blue: 0.62)
}

struct CatKeyboardLockSettingsView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var lockSettings: LockSettings
    @ObservedObject var inputLockController: InputLockController
    @ObservedObject var accessManager: KikiProAccessManager
    let settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>
    @ObservedObject var route: CatKeyboardLockSettingsRouteModel
    let onTriggerOnboarding: () -> Void

    init(
        config: CatKeyboardLockAppConfig,
        lockSettings: LockSettings,
        inputLockController: InputLockController,
        accessManager: KikiProAccessManager,
        settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>,
        route: CatKeyboardLockSettingsRouteModel,
        onTriggerOnboarding: @escaping () -> Void = {}
    ) {
        self.config = config
        self.lockSettings = lockSettings
        self.inputLockController = inputLockController
        self.accessManager = accessManager
        self.settingsCoordinator = settingsCoordinator
        self.route = route
        self.onTriggerOnboarding = onTriggerOnboarding
    }

    var body: some View {
        KikiSettingsCoordinatorView(coordinator: settingsCoordinator) { tab in
            switch tab {
            case .lock:
                lockPane
            case .system:
                systemPane
            case .about:
                aboutPane
            }
        }
        .sheet(isPresented: $route.isPaywallSheetPresented) {
            CatKeyboardLockPaywallSheetView(
                config: config,
                accessManager: accessManager,
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
                value: currentDebugModeDisplayName,
                systemImage: "hammer",
                tone: accessManager.debugProAccessOverride == nil ? .neutral : .warning,
                valueColor: accessManager.debugProAccessOverride == nil ? .secondary : .orange
            )

            KikiSettingsDebugPreviewRow(
                "Pro preview",
                selection: debugModeBinding,
                options: KikiProAccessDebugMode.allCases,
                isOverrideActive: accessManager.debugProAccessOverride != nil,
                optionTitle: { $0.displayName }
            )

            Button("Trigger Onboarding") {
                onTriggerOnboarding()
            }

            Button("Clear Test Override") {
                accessManager.clearDebugProAccessOverride()
            }
            .disabled(accessManager.debugProAccessOverride == nil)
        } header: {
            Text("Developer Testing")
        } footer: {
            KikiSettingsHelperText("Debug builds only. Previews a specific Pro state without making or restoring a purchase.")
        }
    }

    private var currentDebugModeDisplayName: String {
        accessManager.debugProAccessOverride?.displayName ?? "Off"
    }

    private var debugModeBinding: Binding<KikiProAccessDebugMode> {
        Binding(
            get: { accessManager.debugProAccessOverride ?? .live },
            set: { mode in
                if mode == .live {
                    accessManager.clearDebugProAccessOverride()
                } else {
                    accessManager.setDebugProAccessOverride(mode)
                }
            }
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

#if DEBUG
            debugTestingSection
#endif
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
        KikiStandardAboutPane(
            metadata: .bundle(),
            accessStatus: accessStatusPresentation,
            onAccessAction: {
                route.isPaywallSheetPresented = true
            },
            links: KikiStandardAboutLinks(
                website: URL(string: config.officialURL),
                feedback: URL(string: config.contactEmailURL),
                github: URL(string: config.repositoryURL)
            ),
            tint: CatKeyboardLockSettingsTint.brand
        )
    }

    private var accessStatusPresentation: KikiAccessStatusPresentation {
        switch accessManager.status {
        case .notStarted:
            return KikiAccessStatusPresentation(
                tone: .neutral,
                title: "Trial not started",
                subtitle: "Start the free trial when you are ready.",
                actionTitle: "View options"
            )
        case .trial(.time(let daysRemaining, _)):
            return KikiAccessStatusPresentation(
                tone: .trial,
                title: "\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left",
                subtitle: "All Pro controls are available during the trial.",
                actionTitle: "View plans"
            )
        case .trial(.usage(_, let used, let limit)):
            return KikiAccessStatusPresentation(
                tone: .trial,
                title: "\(max(0, limit - used)) uses left",
                subtitle: "All Pro controls are available during the trial.",
                actionTitle: "View plans"
            )
        case .expired:
            return KikiAccessStatusPresentation(
                tone: .expired,
                title: "Trial ended",
                subtitle: "Upgrade to keep using input lock controls.",
                actionTitle: "Upgrade"
            )
        case .pro(let plan, _):
            return KikiAccessStatusPresentation(
                tone: .active,
                title: plan.title,
                subtitle: plan.billingDetail,
                actionTitle: "View plans"
            )
        }
    }
}
