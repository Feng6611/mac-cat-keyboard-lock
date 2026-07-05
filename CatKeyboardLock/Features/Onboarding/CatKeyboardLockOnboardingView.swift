import AppKit
import KikiAuthorization
import KikiWindow
import SwiftUI

@MainActor
final class CatKeyboardLockOnboardingWindowController {
    private let config: CatKeyboardLockAppConfig
    private let proStatusManager: CatKeyboardLockProStatusManager
    private let onboardingState: CatKeyboardLockOnboardingState
    private let inputLockController: InputLockController
    private let onFinish: () -> Void
    private var isCompletingIntentionally = false

    private lazy var windowController = KikiSingleWindowController(
        configuration: .utility(
            title: "Welcome",
            size: CGSize(width: 620, height: 660),
            minimumSize: CGSize(width: 560, height: 560),
            frameAutosaveName: "CatKeyboardLock.OnboardingWindow"
        ),
        onClose: { [weak self] in
            self?.handleWindowClose()
        }
    ) { [weak self, proStatusManager] in
        CatKeyboardLockOnboardingView(
            config: self?.config ?? .default,
            proStatusManager: proStatusManager,
            inputLockController: self?.inputLockController,
            onFinish: {
                self?.finish()
            },
            onClose: {
                self?.skip()
            }
        )
    }

    init(
        config: CatKeyboardLockAppConfig,
        proStatusManager: CatKeyboardLockProStatusManager,
        onboardingState: CatKeyboardLockOnboardingState,
        inputLockController: InputLockController,
        onFinish: @escaping () -> Void
    ) {
        self.config = config
        self.proStatusManager = proStatusManager
        self.onboardingState = onboardingState
        self.inputLockController = inputLockController
        self.onFinish = onFinish
    }

    var isVisible: Bool {
        windowController.isVisible
    }

    func showIfNeeded() {
        guard onboardingState.shouldShow else {
            return
        }

        windowController.show()
    }

    func show() {
        windowController.show()
    }

    private func finish() {
        isCompletingIntentionally = true
        onboardingState.markCompleted()
        windowController.close()
        onFinish()
    }

    private func skip() {
        onboardingState.markCompleted()
        finish()
    }

    private func handleWindowClose() {
        guard !isCompletingIntentionally else {
            isCompletingIntentionally = false
            return
        }

        onboardingState.markCompleted()
        onFinish()
    }
}

struct CatKeyboardLockOnboardingView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager
    @ObservedObject var inputLockController: InputLockController

    let onFinish: () -> Void
    let onClose: () -> Void

    @State private var pageIndex = 0
    @State private var isPaywallSheetPresented = false

    private let pages = CatKeyboardLockOnboardingPage.allCases

    init(
        config: CatKeyboardLockAppConfig,
        proStatusManager: CatKeyboardLockProStatusManager,
        inputLockController: InputLockController?,
        onFinish: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.config = config
        self.proStatusManager = proStatusManager
        self.inputLockController = inputLockController ?? InputLockController(settings: LockSettings())
        self.onFinish = onFinish
        self.onClose = onClose
    }

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
            presentPaywallIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            inputLockController.refreshPermissions()
        }
        .onChange(of: pageIndex) { _ in
            presentPaywallIfNeeded()
        }
        .sheet(isPresented: $isPaywallSheetPresented) {
            CatKeyboardLockPaywallSheetView(
                config: config,
                proStatusManager: proStatusManager,
                context: .onboarding,
                onFinish: onFinish
            )
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        let page = pages[pageIndex]

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
                    .foregroundStyle(inputLockController.permissionStatus.accessibilityTrusted ? Color.secondary : Color.orange)
                    .frame(width: 20)
                Text("Accessibility")
                    .font(.callout.weight(.semibold))
                Spacer(minLength: 0)
                Text(inputLockController.permissionStatus.accessibilityText)
                    .font(.callout)
                    .foregroundStyle(inputLockController.permissionStatus.accessibilityTrusted ? Color.secondary : Color.orange)
            }

            if !inputLockController.permissionStatus.accessibilityTrusted {
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
                    .animation(.easeInOut(duration: 0.18), value: pageIndex)
            }
        }
    }

    private var actionArea: some View {
        HStack(spacing: 12) {
            Button("Skip for now") {
                onClose()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(width: 110, height: 42)

            Spacer(minLength: 0)

            if pageIndex > 0 {
                Button("Back") {
                    pageIndex -= 1
                }
                .buttonStyle(.bordered)
                .frame(width: 82)
            }

            Button {
                handlePrimaryAction()
            } label: {
                HStack(spacing: 8) {
                    Text(primaryButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(width: pageIndex == pages.count - 1 ? 132 : 118, height: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }

    private var primaryButtonTitle: String {
        pageIndex == pages.count - 1 ? "Choose Plan" : "Continue"
    }

    private func handlePrimaryAction() {
        if pageIndex < pages.count - 1 {
            pageIndex += 1
            return
        }

        isPaywallSheetPresented = true
    }

    private func presentPaywallIfNeeded() {
        guard pages[pageIndex] == .trial else {
            return
        }

        DispatchQueue.main.async {
            isPaywallSheetPresented = true
        }
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
