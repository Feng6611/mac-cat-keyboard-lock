import AppKit
import KikiWindow
import SwiftUI

@MainActor
final class CatKeyboardLockOnboardingWindowController {
    private let proStatusManager: CatKeyboardLockProStatusManager
    private let onFinish: () -> Void
    private var isCompletingIntentionally = false

    private lazy var windowController = KikiSingleWindowController(
        configuration: .utility(
            title: "Welcome",
            size: CGSize(width: 560, height: 560),
            minimumSize: CGSize(width: 520, height: 520),
            frameAutosaveName: "CatKeyboardLock.OnboardingWindow"
        ),
        onClose: { [weak self] in
            self?.handleWindowClose()
        }
    ) { [weak self, proStatusManager] in
        CatKeyboardLockOnboardingView(
            proStatusManager: proStatusManager,
            onFinish: {
                self?.finish()
            },
            onClose: {
                self?.skip()
            }
        )
    }

    init(proStatusManager: CatKeyboardLockProStatusManager, onFinish: @escaping () -> Void) {
        self.proStatusManager = proStatusManager
        self.onFinish = onFinish
    }

    var isVisible: Bool {
        windowController.isVisible
    }

    func showIfNeeded() {
        guard proStatusManager.shouldShowOnboarding else {
            return
        }

        windowController.show()
    }

    func show() {
        windowController.show()
    }

    private func finish() {
        isCompletingIntentionally = true
        windowController.close()
        onFinish()
    }

    private func skip() {
        proStatusManager.completeOnboardingWithoutTrial()
        finish()
    }

    private func handleWindowClose() {
        guard !isCompletingIntentionally else {
            isCompletingIntentionally = false
            return
        }

        proStatusManager.completeOnboardingWithoutTrial()
        onFinish()
    }
}

struct CatKeyboardLockOnboardingView: View {
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager

    let onFinish: () -> Void
    let onClose: () -> Void

    @State private var pageIndex = 0
    @State private var isStartingTrial = false

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
        .frame(width: 560, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var pageContent: some View {
        let page = pages[pageIndex]

        return VStack(spacing: 18) {
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
        }
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
                    if isStartingTrial {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(primaryButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(width: pageIndex == pages.count - 1 ? 190 : 118, height: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isStartingTrial)
        }
    }

    private var primaryButtonTitle: String {
        if pageIndex == pages.count - 1 {
            return "Start 2-Day Pro Trial"
        }

        return "Continue"
    }

    private func handlePrimaryAction() {
        if pageIndex < pages.count - 1 {
            pageIndex += 1
            return
        }

        Task { @MainActor in
            isStartingTrial = true
            await proStatusManager.startTrial()
            isStartingTrial = false
            onFinish()
        }
    }
}

private enum CatKeyboardLockOnboardingPage: CaseIterable {
    case protect
    case recover
    case trial

    var systemImage: String {
        switch self {
        case .protect:
            return "keyboard.badge.ellipsis"
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
        case .recover:
            return "Recovery stays simple"
        case .trial:
            return "Try the full lock for 2 days"
        }
    }

    var subtitle: String {
        switch self {
        case .protect:
            return "Cat Keyboard Lock keeps accidental typing, clicks, movement, and scrolls away from the current Mac session."
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
                "Keyboard, click, and pointer movement locks",
                "Manual menu bar control"
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
