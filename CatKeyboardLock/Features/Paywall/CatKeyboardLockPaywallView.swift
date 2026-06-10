import AppKit
import SwiftUI

private enum CatKeyboardLockPaywallColors {
    static let brandAccent = Color(red: 0.58, green: 0.20, blue: 0.62)
}

enum CatKeyboardLockPaywallContext {
    case settings
    case onboarding
}

struct CatKeyboardLockPaywallDisplayState {
    let status: CatKeyboardLockProStatus

    var isExpired: Bool {
        if case .expired = status {
            return true
        }
        return false
    }

    var isPro: Bool {
        status.isPro
    }
}

struct CatKeyboardLockPaywallSheetView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager
    let context: CatKeyboardLockPaywallContext
    let onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(
        config: CatKeyboardLockAppConfig,
        proStatusManager: CatKeyboardLockProStatusManager,
        context: CatKeyboardLockPaywallContext,
        onFinish: (() -> Void)? = nil
    ) {
        self.config = config
        self.proStatusManager = proStatusManager
        self.context = context
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                CatKeyboardLockPaywallView(
                    config: config,
                    proStatusManager: proStatusManager,
                    context: context,
                    onFinish: finish
                )
                .padding(.horizontal, 34)
                .padding(.vertical, 32)
            }

            if context == .settings {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(18)
                .accessibilityLabel("Close")
            }
        }
        .frame(width: 560, height: 620)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                RadialGradient(
                    colors: [
                        CatKeyboardLockPaywallColors.brandAccent.opacity(0.06),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 360
                )
            }
        }
    }

    private func finish() {
        dismiss()
        onFinish?()
    }
}

struct CatKeyboardLockPaywallView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager
    let context: CatKeyboardLockPaywallContext
    let onFinish: (() -> Void)?

    private var displayState: CatKeyboardLockPaywallDisplayState {
        CatKeyboardLockPaywallDisplayState(status: proStatusManager.status)
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 10, y: 5)

            Text(displayState.isPro ? "Cat Lock Pro" : "Choose your plan")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(displayState.isPro ? "All Pro controls are unlocked." : "Keep keyboard and click locking available when you need it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if displayState.isPro {
                CatKeyboardLockProStatusCard(
                    proStatusManager: proStatusManager,
                    config: config
                )
            } else {
                CatKeyboardLockUpgradeCard(
                    config: config,
                    proStatusManager: proStatusManager,
                    context: context,
                    onFinish: onFinish
                )
            }
        }
        .frame(maxWidth: 500)
    }
}

private struct CatKeyboardLockUpgradeCard: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager
    let context: CatKeyboardLockPaywallContext
    let onFinish: (() -> Void)?

    @State private var selectedPlan: CatKeyboardLockPurchasePlan = .defaultSelection
    @State private var isLoadingOfferings = false
    @State private var isStartingTrial = false

    private var displayState: CatKeyboardLockPaywallDisplayState {
        CatKeyboardLockPaywallDisplayState(status: proStatusManager.status)
    }

    private var selectedProduct: CatKeyboardLockProPlanProduct {
        proStatusManager.planProduct(for: selectedPlan)
    }

    private var isBusy: Bool {
        isLoadingOfferings
            || isStartingTrial
            || proStatusManager.purchaseInProgressPlan != nil
            || proStatusManager.isRestoringPurchases
    }

    private var shouldUseTrialPrimaryAction: Bool {
        context == .onboarding && proStatusManager.status.canStartTrial
    }

    var body: some View {
        VStack(spacing: 0) {
            heroSection
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(displayState.isExpired ? Color.orange.opacity(0.10) : CatKeyboardLockPaywallColors.brandAccent.opacity(0.08))

            Divider()

            VStack(spacing: 9) {
                ForEach(proStatusManager.availablePlans) { product in
                    planRow(product)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            messageArea
                .padding(.horizontal, 20)
                .padding(.top, 10)

            primaryButton
                .padding(.horizontal, 20)
                .padding(.top, 14)

            if let secondaryActionTitle {
                Button {
                    Task { await startTrial() }
                } label: {
                    Text(secondaryActionTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            footerLinks
                .padding(.top, 14)
                .padding(.bottom, 18)
        }
        .paywallCard()
        .task {
            await loadOfferings()
        }
        .onChange(of: proStatusManager.availablePlans) { _ in
            syncSelectedPlan()
        }
    }

    private var heroSection: some View {
        HStack(spacing: 14) {
            PaywallIconBadge(
                systemName: displayState.isExpired ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                iconColor: displayState.isExpired ? .orange : CatKeyboardLockPaywallColors.brandAccent,
                backgroundColor: displayState.isExpired ? Color.orange.opacity(0.14) : CatKeyboardLockPaywallColors.brandAccent.opacity(0.14)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("Cat Lock Pro")
                    .font(.title3.weight(.bold))

                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(statusSubtitleColor)
            }

            Spacer(minLength: 0)
        }
    }

    private func planRow(_ product: CatKeyboardLockProPlanProduct) -> some View {
        let isSelected = selectedPlan == product.plan

        return Button {
            guard product.isAvailable, !isBusy else {
                return
            }

            withAnimation(.easeInOut(duration: 0.15)) {
                selectedPlan = product.plan
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? CatKeyboardLockPaywallColors.brandAccent : Color(nsColor: .separatorColor),
                            lineWidth: 1.5
                        )
                        .frame(width: 18, height: 18)

                    if isSelected {
                        Circle()
                            .fill(CatKeyboardLockPaywallColors.brandAccent)
                            .frame(width: 8, height: 8)
                    }
                }

                HStack(spacing: 6) {
                    Text(product.title)
                        .font(.callout.weight(.medium))

                    if let badge = product.badge {
                        PaywallPill(text: badge, tone: .accent)
                    }

                    if !product.isAvailable {
                        PaywallPill(text: "Unavailable", tone: .neutral)
                    }
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .foregroundStyle(isSelected ? CatKeyboardLockPaywallColors.brandAccent : .primary)
                    Text("once")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? CatKeyboardLockPaywallColors.brandAccent.opacity(0.06) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? CatKeyboardLockPaywallColors.brandAccent.opacity(0.50) : Color(nsColor: .separatorColor).opacity(0.45),
                        lineWidth: isSelected ? 1.25 : 0.75
                    )
            )
            .opacity(product.isAvailable ? 1 : 0.52)
        }
        .buttonStyle(.plain)
        .disabled(!product.isAvailable || isBusy)
    }

    @ViewBuilder
    private var messageArea: some View {
        if let paywallErrorMessage = proStatusManager.paywallErrorMessage {
            message(paywallErrorMessage, color: .red)
        } else if let successMessage = proStatusManager.paywallSuccessMessage {
            message(successMessage, color: .green)
        } else if isLoadingOfferings {
            message("Loading purchase options...", color: .secondary)
        } else if displayState.isExpired {
            message("Trial ended. Your saved settings stay intact after upgrading.", color: .orange)
        } else if !selectedProduct.isAvailable && !shouldUseTrialPrimaryAction {
            message("Purchase options are not available right now. You can try again later or restore an existing purchase.", color: .secondary)
        }
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.10))
            )
    }

    private var primaryButton: some View {
        Button {
            Task { await runPrimaryAction() }
        } label: {
            HStack(spacing: 8) {
                if primaryIsLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: shouldUseTrialPrimaryAction ? "sparkles" : "lock.open.fill")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(primaryButtonTitle)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: primaryGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!primaryIsEnabled)
        .opacity(primaryIsEnabled ? 1 : 0.72)
    }

    private var footerLinks: some View {
        HStack(spacing: 10) {
            Button(proStatusManager.isRestoringPurchases ? "Restoring..." : "Restore Purchase") {
                Task { await restorePurchases() }
            }
            .buttonStyle(.link)
            .font(.caption)
            .disabled(isBusy)

            PaywallDotSeparator()

            Button("Privacy") {
                openURL(config.privacyURL)
            }
            .buttonStyle(.link)
            .font(.caption)

            PaywallDotSeparator()

            Button("Support") {
                openURL(config.supportURL)
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }

    private var statusSubtitle: String {
        switch proStatusManager.status {
        case .notStarted:
            return "Start the trial when you are ready"
        case .trial(let daysRemaining, _):
            return "\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left in your Pro trial"
        case .expired:
            return "Your trial has ended"
        case .pro:
            return ""
        }
    }

    private var statusSubtitleColor: Color {
        switch proStatusManager.status {
        case .expired:
            return .orange
        case .trial(let daysRemaining, _) where daysRemaining <= 2:
            return .orange
        default:
            return .secondary
        }
    }

    private var primaryButtonTitle: String {
        if shouldUseTrialPrimaryAction {
            return "Start 2-Day Pro Trial"
        }

        guard selectedProduct.isAvailable else {
            return isLoadingOfferings ? "Loading Purchase Options..." : "Currently Unavailable"
        }

        return "Unlock Forever - \(selectedProduct.displayPrice)"
    }

    private var primaryGradientColors: [Color] {
        primaryIsEnabled
            ? [CatKeyboardLockPaywallColors.brandAccent, CatKeyboardLockPaywallColors.brandAccent.opacity(0.78)]
            : [Color.secondary.opacity(0.62), Color.secondary.opacity(0.46)]
    }

    private var primaryIsEnabled: Bool {
        if shouldUseTrialPrimaryAction {
            return !isBusy
        }

        return !isBusy && selectedProduct.isAvailable
    }

    private var primaryIsLoading: Bool {
        if shouldUseTrialPrimaryAction {
            return isStartingTrial
        }

        return isLoadingOfferings || proStatusManager.purchaseInProgressPlan == selectedPlan
    }

    private var secondaryActionTitle: String? {
        guard context == .settings, proStatusManager.status.canStartTrial else {
            return nil
        }
        return "Start 2-Day Pro Trial"
    }

    private func loadOfferings() async {
        isLoadingOfferings = true
        await proStatusManager.loadOfferings()
        syncSelectedPlan()
        isLoadingOfferings = false
    }

    private func syncSelectedPlan() {
        if proStatusManager.planProduct(for: selectedPlan).isAvailable {
            return
        }

        if let firstAvailablePlan = proStatusManager.availablePlans.first(where: { $0.isAvailable })?.plan {
            selectedPlan = firstAvailablePlan
        }
    }

    private func runPrimaryAction() async {
        if shouldUseTrialPrimaryAction {
            await startTrial()
            return
        }

        await purchaseSelectedPlan()
    }

    private func purchaseSelectedPlan() async {
        guard selectedProduct.isAvailable else {
            return
        }

        do {
            try await proStatusManager.purchase(selectedPlan)
            if proStatusManager.status.isPro {
                onFinish?()
            }
        } catch {
            // User-facing error state is owned by the status manager.
        }
    }

    private func startTrial() async {
        isStartingTrial = true
        await proStatusManager.startTrial()
        isStartingTrial = false
        if proStatusManager.status.isActive {
            onFinish?()
        }
    }

    private func restorePurchases() async {
        guard !proStatusManager.isRestoringPurchases else {
            return
        }

        do {
            try await proStatusManager.restorePurchases()
            if proStatusManager.status.isPro {
                onFinish?()
            }
        } catch {
            // User-facing error state is owned by the status manager.
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private struct CatKeyboardLockProStatusCard: View {
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager
    let config: CatKeyboardLockAppConfig

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                PaywallIconBadge(
                    systemName: "checkmark.seal.fill",
                    iconColor: CatKeyboardLockPaywallColors.brandAccent,
                    backgroundColor: CatKeyboardLockPaywallColors.brandAccent.opacity(0.14),
                    size: 58
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text("Pro")
                            .font(.title2.weight(.bold))

                        if let badgeTitle {
                            PaywallPill(text: badgeTitle, tone: .accent)
                        }
                    }

                    Text("All Cat Keyboard Lock Pro features are unlocked. Thank you for your support.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(CatKeyboardLockPaywallColors.brandAccent.opacity(0.08))

            VStack(spacing: 0) {
                metadataRow(title: "Status", value: "Active")

                if let memberSince {
                    Divider().padding(.leading, 20)
                    metadataRow(title: "Member since", value: memberSince)
                }

                Divider().padding(.leading, 20)

                HStack(spacing: 10) {
                    Button("Privacy") {
                        openURL(config.privacyURL)
                    }
                    .buttonStyle(.link)
                    .font(.caption)

                    PaywallDotSeparator()

                    Button("Support") {
                        openURL(config.supportURL)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding(.vertical, 14)
            }
        }
        .paywallCard()
    }

    private var badgeTitle: String? {
        guard case .pro(let plan, _) = proStatusManager.status else {
            return nil
        }
        return plan.title
    }

    private var memberSince: String? {
        guard case .pro(_, let originalPurchaseDate) = proStatusManager.status,
              let originalPurchaseDate else {
            return nil
        }
        return originalPurchaseDate.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.callout)
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private struct PaywallIconBadge: View {
    let systemName: String
    let iconColor: Color
    let backgroundColor: Color
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
            .frame(width: size, height: size)
            .background(Circle().fill(backgroundColor))
    }
}

private struct PaywallPill: View {
    enum Tone {
        case accent
        case neutral
    }

    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tone == .accent ? Color.white : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tone == .accent ? CatKeyboardLockPaywallColors.brandAccent : Color.secondary.opacity(0.12))
            )
    }
}

private struct PaywallDotSeparator: View {
    var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 3, height: 3)
    }
}

private extension View {
    func paywallCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }
}
