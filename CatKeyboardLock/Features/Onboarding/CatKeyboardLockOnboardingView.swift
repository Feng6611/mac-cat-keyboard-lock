import AppKit
import KikiAuthorization
import KikiCommerceCore
import KikiDesign
import KikiOnboarding
import KikiTriggerCorner
import SwiftUI

enum CatKeyboardLockOnboardingFlow {
    static let windowSize = KikiOnboardingDefaults.windowSize

    @MainActor
    static func makeCoordinator(
        config: CatKeyboardLockAppConfig,
        accessManager: KikiAccessManager,
        onboardingState: CatKeyboardLockOnboardingState,
        lockSettings: LockSettings,
        inputLockController: InputLockController,
        onFinish: @escaping @MainActor () -> Void
    ) -> KikiOnboardingCoordinator {
        let flow = KikiOnboardingStep.custom(id: "cat-lock-guided-flow") { navigation in
            AnyView(
                CatKeyboardLockOnboardingFlowView(
                    config: config,
                    accessManager: accessManager,
                    lockSettings: lockSettings,
                    inputLockController: inputLockController,
                    onFinish: navigation.finish
                )
            )
        }

        return KikiOnboardingCoordinator(
            configuration: KikiOnboardingConfiguration(
                appName: config.appName,
                steps: [flow],
                completionKey: CatKeyboardLockOnboardingState.completionKey,
                canSkip: false,
                tint: CatKeyboardLockSettingsTint.brand,
                windowAutosaveName: "CatKeyboardLock.OnboardingWindow",
                windowTitle: "Welcome",
                windowSize: windowSize,
                minimumWindowSize: windowSize,
                closeDisposition: .complete
            ),
            completionStore: onboardingState.store,
            onFinished: onFinish
        )
    }
}

private struct CatKeyboardLockOnboardingFlowView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var accessManager: KikiAccessManager
    @ObservedObject var inputLockController: InputLockController
    @StateObject private var session: CatKeyboardLockOnboardingSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tint = CatKeyboardLockSettingsTint.brand

    init(
        config: CatKeyboardLockAppConfig,
        accessManager: KikiAccessManager,
        lockSettings: LockSettings,
        inputLockController: InputLockController,
        onFinish: @escaping @MainActor () -> Void
    ) {
        self.config = config
        self.accessManager = accessManager
        self.inputLockController = inputLockController
        _session = StateObject(
            wrappedValue: CatKeyboardLockOnboardingSession(
                lockSettings: lockSettings,
                inputLockController: inputLockController,
                onFinish: onFinish
            )
        )
    }

    var body: some View {
        ZStack {
            page
                .id(session.phase)
                .transition(pageTransition)
        }
        .animation(
            .easeInOut(duration: reduceMotion ? 0.18 : 0.34),
            value: session.phase
        )
        .onAppear(perform: session.start)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            session.refreshAccessibility()
        }
        .sheet(
            isPresented: $session.isPaywallPresented,
            onDismiss: session.complete
        ) {
            CatKeyboardLockPaywallSheetView(
                config: config,
                accessManager: accessManager,
                context: .onboarding,
                onFinish: session.complete
            )
        }
    }

    private var pageTransition: AnyTransition {
        guard reduceMotion == false else {
            return .opacity
        }

        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var page: some View {
        KikiOnboardingScaffold(
            appName: config.appName,
            title: session.phase.title,
            bodyText: session.phase.subtitle,
            appIcon: session.phase == .welcome ? KikiApplicationIcon.current : nil,
            iconSystemName: session.phase.systemImage,
            primaryAction: primaryAction,
            tint: tint,
            size: CatKeyboardLockOnboardingFlow.windowSize,
            stepIndex: session.phase.progressIndex,
            stepCount: 4
        ) {
            pageContent
        }
    }

    private var primaryAction: KikiOnboardingAction {
        switch session.phase {
        case .welcome:
            return KikiOnboardingAction(title: "Continue", action: session.advance)
        case .permission:
            return KikiOnboardingAction(title: "Allow Accessibility", action: session.requestAccessibility)
        case .permissionSuccess, .lockSuccess, .unlockSuccess:
            return KikiOnboardingAction(title: "Continue", action: session.advance)
        case .lockWithCorner:
            return KikiOnboardingAction(title: "Waiting for trigger corner…", isEnabled: false) {}
        case .unlockWithCorner:
            return KikiOnboardingAction(title: "Waiting for trigger corner…", isEnabled: false) {}
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch session.phase {
        case .welcome:
            featureRows
        case .permission:
            KikiOnboardingPermissionRow(
                panel: .accessibility,
                instruction: "Allow Cat Keyboard Lock to block keyboard input while locked.",
                tint: tint
            )
            .frame(maxWidth: 390)
        case .permissionSuccess:
            CatKeyboardLockCelebrationMark(tint: tint, title: "Permission granted")
        case .lockWithCorner:
            triggerCornerGuide(isUnlock: false)
        case .lockSuccess:
            CatKeyboardLockCelebrationMark(tint: tint, title: "Keyboard locked")
        case .unlockWithCorner:
            triggerCornerGuide(isUnlock: true)
        case .unlockSuccess:
            CatKeyboardLockCelebrationMark(tint: tint, title: "Keyboard restored")
        }
    }

    private var featureRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow("Block accidental keyboard input")
            featureRow("Lock and unlock from a trigger corner")
            featureRow("Always keep a safety release available")
        }
        .frame(maxWidth: 380, alignment: .leading)
    }

    private func featureRow(_ title: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func triggerCornerGuide(isUnlock: Bool) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: cornerAlignment) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 230, height: 118)

                Circle()
                    .fill(tint)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: "cursorarrow")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(10)
            }

            Text(isUnlock ? "Move out, then return to the corner and hold." : "Move the pointer into the corner and hold.")
                .font(.callout.weight(.medium))
            Text(session.triggerCorner.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cornerAlignment: Alignment {
        switch session.triggerCorner {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }
}

private extension CatKeyboardLockOnboardingPhase {
    var systemImage: String {
        switch self {
        case .welcome: return "keyboard.badge.ellipsis"
        case .permission: return KikiAuthorizationPanel.accessibility.systemImage
        case .permissionSuccess: return "checkmark.seal.fill"
        case .lockWithCorner: return "cursorarrow.motionlines"
        case .lockSuccess: return "lock.fill"
        case .unlockWithCorner: return "cursorarrow.motionlines"
        case .unlockSuccess: return "lock.open.fill"
        }
    }

    var title: String {
        switch self {
        case .welcome: return "Lock input when you step away"
        case .permission: return "Allow Accessibility"
        case .permissionSuccess: return "Accessibility is ready"
        case .lockWithCorner: return "Lock from the trigger corner"
        case .lockSuccess: return "Locked!"
        case .unlockWithCorner: return "Use the corner again"
        case .unlockSuccess: return "Unlocked!"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "Cat Keyboard Lock keeps accidental typing and clicks away from the current Mac session."
        case .permission:
            return "macOS requires this permission before the app can block keyboard input."
        case .permissionSuccess:
            return "The app can now protect your keyboard."
        case .lockWithCorner:
            return "Practice the same gesture you will use every day."
        case .lockSuccess:
            return "The trigger corner blocked keyboard input."
        case .unlockWithCorner:
            return "Leave the corner, then trigger it once more to restore input."
        case .unlockSuccess:
            return "You now know how to lock and recover your keyboard."
        }
    }
}
