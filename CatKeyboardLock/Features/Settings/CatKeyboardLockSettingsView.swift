import Foundation
import KikiAuthorization
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

enum CatKeyboardLockSettingsTint {
    // Defined by Assets.xcassets/AccentColor so every system control shares
    // the brand tint and adapts with appearance changes.
    static let brand = Color.accentColor
}

struct CatKeyboardLockSettingsView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var lockSettings: LockSettings
    @ObservedObject var inputLockController: InputLockController
    @ObservedObject var supportState: CatKeyboardLockSupportState
    let settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>
    let onTriggerOnboarding: () -> Void

    init(
        config: CatKeyboardLockAppConfig,
        lockSettings: LockSettings,
        inputLockController: InputLockController,
        supportState: CatKeyboardLockSupportState,
        settingsCoordinator: KikiSettingsCoordinator<CatKeyboardLockSettingsTab>,
        onTriggerOnboarding: @escaping () -> Void = {}
    ) {
        self.config = config
        self.lockSettings = lockSettings
        self.inputLockController = inputLockController
        self.supportState = supportState
        self.settingsCoordinator = settingsCoordinator
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
    }

    private var lockPane: some View {
        KikiSettingsPane {
            Section {
                KikiSettingsToggleRow("Keyboard", isOn: $lockSettings.lockKeyboard, systemImage: "keyboard")
                KikiSettingsToggleRow("Clicks", isOn: $lockSettings.lockMouseClicks)
            } footer: {
                KikiSettingsHelperText(
                    "Keyboard input is blocked by default. Turn on Clicks to block mouse and trackpad clicks too."
                )
            }

            Section {
                lockDurationRow
                lockFeedbackRow
            } header: {
                Text("Safety")
            } footer: {
                KikiSettingsHelperText(
                    "Unlock from the menu bar or trigger corner. If clicks are locked and the trigger corner is off, input returns when the selected duration ends."
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
            debugSupportSection
#endif
        }
    }

#if DEBUG
    private var debugSupportSection: some View {
        Section {
            KikiSettingsValueRow(
                "Support status",
                systemImage: "heart.fill",
                iconColor: CatKeyboardLockSettingsTint.brand
            ) {
                Button(supportState.didSupport ? "Show support ask" : "Hide support ask") {
                    supportState.toggleSupportedForDebug()
                }
                .buttonStyle(.bordered)

                Text(supportState.didSupport ? "Supported" : "Not supported")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Developer Testing")
        } footer: {
            KikiSettingsHelperText("Debug only. Support is optional and never unlocks features.")
        }
    }
#endif

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

    // Built from KikiAboutPane instead of KikiStandardAboutPane so the tip jar
    // can be a real card rather than one more grey link row.
    private var aboutPane: some View {
        let metadata = KikiAppMetadata.bundle()

        return KikiAboutPane(
            appName: metadata.appName,
            versionText: metadata.displayVersion,
            status: {
                KikiSettingsStatusRow(
                    title: "Status",
                    value: "Free forever",
                    systemImage: "info.circle",
                    valueSystemImage: "checkmark.seal",
                    tone: .accent,
                    tint: CatKeyboardLockSettingsTint.brand,
                    showsBadge: false
                )
                KikiSettingsHelperText("No trial, no subscription, no in-app purchase, and no account.")
            },
            links: {
                supportRow

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
            }
        )
    }

    @ViewBuilder
    private var supportRow: some View {
        if supportState.showsAboutCard {
            CatKeyboardLockSupportCard(
                tint: CatKeyboardLockSettingsTint.brand,
                onTryCommandReopen: { CatKeyboardLockSupportLinks.openCommandReopen(config) },
                onStar: { CatKeyboardLockSupportLinks.openRepository(config) },
                onFollowX: { CatKeyboardLockSupportLinks.openXProfile(config) },
                onTip: { CatKeyboardLockSupportLinks.openTipPage(config) },
                onAlreadySupported: supportState.markSupported
            )
        } else {
            KikiSettingsValueRow(
                "Thanks for the can",
                systemImage: "heart.fill",
                iconColor: CatKeyboardLockSettingsTint.brand
            ) {
                Text("Cat Lock will not ask again.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
