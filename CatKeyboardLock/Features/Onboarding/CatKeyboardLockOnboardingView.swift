import AppKit
import KikiAuthorization
import KikiCommerceCore
import KikiOnboarding
import SwiftUI

enum CatKeyboardLockOnboardingFlow {
    @MainActor
    static func makeCoordinator(
        config: CatKeyboardLockAppConfig,
        accessManager: KikiProAccessManager,
        onboardingState: CatKeyboardLockOnboardingState,
        inputLockController: InputLockController,
        onFinish: @escaping @MainActor () -> Void
    ) -> KikiOnboardingCoordinator {
        let steps = CatKeyboardLockOnboardingPage.allCases.map { page in
            KikiOnboardingStep.custom(id: page.rawValue) { navigation in
                if page == .trial {
                    return AnyView(
                        CatKeyboardLockPaywallSheetView(
                            config: config,
                            accessManager: accessManager,
                            context: .onboarding,
                            onFinish: navigation.finish
                        )
                    )
                }

                return AnyView(
                    CatKeyboardLockOnboardingStepView(
                        page: page,
                        inputLockController: inputLockController,
                        navigation: navigation
                    )
                )
            }
        }

        return KikiOnboardingCoordinator(
            configuration: KikiOnboardingConfiguration(
                appName: config.appName,
                steps: steps,
                completionKey: CatKeyboardLockOnboardingState.completionKey,
                canSkip: true,
                tint: .orange,
                windowAutosaveName: "CatKeyboardLock.OnboardingWindow",
                windowTitle: "Welcome",
                windowSize: CGSize(width: 620, height: 660),
                minimumWindowSize: CGSize(width: 560, height: 560),
                closeDisposition: .complete
            ),
            completionStore: onboardingState.store,
            onFinished: onFinish
        )
    }
}

private struct CatKeyboardLockOnboardingStepView: View {
    let page: CatKeyboardLockOnboardingPage
    @ObservedObject var inputLockController: InputLockController
    let navigation: KikiOnboardingNavigation

    private let pages = CatKeyboardLockOnboardingPage.allCases

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)

            pageContent
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 42)

            Spacer(minLength: 20)

            pageIndicators
                .padding(.bottom, 18)

            actionArea
                .padding(.horizontal, 34)
                .padding(.bottom, 26)
        }
        .frame(width: 620, height: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            inputLockController.refreshPermissions()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            inputLockController.refreshPermissions()
        }
    }

    private var pageContent: some View {
        VStack(spacing: 18) {
            Image(systemName: page.systemImage)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 88, height: 88)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.orange.opacity(0.09))
                )

            Text(page.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 410)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(page.points, id: \.self) { point in
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 18)
                        Text(point)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: 380, alignment: .leading)
            .padding(.top, 2)

            if page == .permission {
                permissionCard
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: KikiAuthorizationPanel.accessibility.systemImage)
                    .foregroundStyle(
                        inputLockController.permissionStatus.accessibilityTrusted
                            ? Color.secondary
                            : Color.orange
                    )
                    .frame(width: 20)
                Text("Accessibility")
                    .font(.callout.weight(.semibold))
                Spacer(minLength: 0)
                Text(inputLockController.permissionStatus.accessibilityText)
                    .font(.callout)
                    .foregroundStyle(
                        inputLockController.permissionStatus.accessibilityTrusted
                            ? Color.secondary
                            : Color.orange
                    )
            }

            if inputLockController.permissionStatus.accessibilityTrusted == false {
                Button("Open Accessibility Settings") {
                    inputLockController.requestPermissions()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: 380, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var pageIndicators: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == pageIndex ? Color.orange : Color.secondary.opacity(0.25))
                    .frame(width: index == pageIndex ? 22 : 7, height: 7)
            }
        }
    }

    private var actionArea: some View {
        HStack(spacing: 12) {
            Button("Skip for now") {
                navigation.skip()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(width: 110, height: 42)

            Spacer(minLength: 0)

            if pageIndex > 0 {
                Button("Back") {
                    navigation.back()
                }
                .buttonStyle(.bordered)
                .frame(width: 82)
            }

            Button("Continue") {
                navigation.advance()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .frame(width: 118, height: 32)
        }
    }

    private var pageIndex: Int {
        pages.firstIndex(of: page) ?? 0
    }
}

enum CatKeyboardLockOnboardingPage: String, CaseIterable {
    case protect
    case permission
    case recover
    case trial

    var systemImage: String {
        switch self {
        case .protect:
            return "keyboard.badge.ellipsis"
        case .permission:
            return "accessibility"
        case .recover:
            return "lock.rotation"
        case .trial:
            return "sparkles"
        }
    }

    var title: String {
        switch self {
        case .protect:
            return "Lock input when you step away"
        case .permission:
            return "Set up Accessibility"
        case .recover:
            return "Recovery stays simple"
        case .trial:
            return "Try the full lock for 2 days"
        }
    }

    var subtitle: String {
        switch self {
        case .protect:
            return "Cat Keyboard Lock keeps accidental typing and clicks away from the current Mac session."
        case .permission:
            return "macOS requires Accessibility before an app can block input. You can finish setup now or continue and grant it later."
        case .recover:
            return "The app favors safe recovery: menu unlock, automatic timeout, and a fallback shortcut remain available."
        case .trial:
            return "Start once when you are ready. During the trial, every Pro control is available."
        }
    }

    var points: [String] {
        switch self {
        case .protect:
            return [
                "Keyboard and click locks",
                "Manual menu bar control"
            ]
        case .permission:
            return [
                "Used only for the active input lock",
                "Settings and menu controls remain reachable"
            ]
        case .recover:
            return [
                "Hold Control + Option + Command + L for 1 second",
                "Timeout releases input automatically"
            ]
        case .trial:
            return [
                "No trial time is used until you start",
                "Upgrade once to keep Pro permanently"
            ]
        }
    }
}
