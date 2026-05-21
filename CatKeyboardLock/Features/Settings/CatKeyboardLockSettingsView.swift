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

struct CatKeyboardLockSettingsView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var lockSettings: LockSettings
    @ObservedObject var inputLockController: InputLockController
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager
    let openPaywall: () -> Void
    @StateObject private var navigation = KikiSettingsNavigationModel<CatKeyboardLockSettingsTab>(selectedTab: .lock)

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
    }

    private var lockPane: some View {
        KikiSettingsPane {
            Section {
                KikiSettingsStatusRow(
                    title: "Pro access",
                    value: proStatusManager.status.displayName,
                    systemImage: "sparkles",
                    valueColor: proStatusManager.status.isActive ? .secondary : .orange
                )

                if !proStatusManager.status.isActive {
                    Button(proStatusManager.status.canStartTrial ? "Start Trial / Upgrade..." : "Upgrade to Pro...") {
                        openPaywall()
                    }
                }
            } footer: {
                if !proStatusManager.status.isActive {
                    KikiSettingsHelperText("Start the trial or upgrade to enable input locking controls.")
                }
            }

#if DEBUG
            debugTestingSection
#endif

            Section {
                KikiSettingsToggleRow("Keyboard", isOn: $lockSettings.lockKeyboard, systemImage: "keyboard")
                KikiSettingsToggleRow("Clicks", isOn: $lockSettings.lockMouseClicks)
                KikiSettingsToggleRow("Movement", isOn: $lockSettings.lockPointerMovement)
            } footer: {
                KikiSettingsHelperText(
                    "Keyboard is the core lock. Clicks and movement are optional extensions; movement includes dragging and scrolling."
                )
            }
            .disabled(!proStatusManager.status.isActive)

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
            .disabled(!proStatusManager.status.isActive)

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
            .disabled(!proStatusManager.status.isActive)
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
                KikiSettingsStatusRow(
                    title: "Accessibility",
                    value: inputLockController.permissionStatus.accessibilityText,
                    valueColor: inputLockController.permissionStatus.accessibilityTrusted ? .secondary : .orange
                )

                if !inputLockController.permissionStatus.accessibilityTrusted {
                    Button("Grant Accessibility Access") {
                        inputLockController.requestPermissions()
                    }
                }
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
        KikiAboutPane(
            appName: config.appName,
            versionText: "Cat Keyboard Lock 1.0"
        ) {
            KikiSettingsStatusRow(
                title: "Mode",
                value: "Manual menu bar lock",
                systemImage: "menubar.rectangle"
            )
            KikiSettingsStatusRow(
                title: "Privacy",
                value: "Local only",
                systemImage: "lock.shield"
            )
            KikiSettingsStatusRow(
                title: "Plan",
                value: proStatusManager.status.displayName,
                systemImage: "sparkles"
            )
        } links: {
            KikiSettingsLinkRow(
                title: "Built with Kiki",
                value: "Framework",
                urlString: config.supportURL,
                systemImage: "shippingbox"
            )
            KikiSettingsLinkRow(
                title: "Source code",
                value: "GitHub",
                urlString: config.repositoryURL,
                systemImage: "chevron.left.forwardslash.chevron.right"
            )
            KikiSettingsCopyRow(
                title: "Bundle ID",
                value: "dev.kkuk.catkeyboardlock",
                systemImage: "number"
            )
        }
    }

}
