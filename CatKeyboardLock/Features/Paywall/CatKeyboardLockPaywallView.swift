import KikiPaywall
import SwiftUI

@MainActor
final class CatKeyboardLockPaywallWindowController {
    private let config: CatKeyboardLockAppConfig
    private let proStatusManager: CatKeyboardLockProStatusManager
    private lazy var windowController = KikiPaywallWindowController(
        title: "Upgrade",
        size: CGSize(
            width: KikiPaywallDefaults.windowWidth,
            height: KikiPaywallDefaults.windowHeight
        ),
        frameAutosaveName: "CatKeyboardLock.PaywallWindow"
    ) { [config, proStatusManager] in
        CatKeyboardLockPaywallView(config: config, proStatusManager: proStatusManager)
    }

    init(config: CatKeyboardLockAppConfig, proStatusManager: CatKeyboardLockProStatusManager) {
        self.config = config
        self.proStatusManager = proStatusManager
    }

    func show() {
        windowController.show()
    }
}

struct CatKeyboardLockPaywallView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager

    @State private var selectedPlan: CatKeyboardLockPurchasePlan = .defaultSelection
    @State private var isLoadingOfferings = false
    @State private var isStartingTrial = false

    init(config: CatKeyboardLockAppConfig, proStatusManager: CatKeyboardLockProStatusManager) {
        self.config = config
        self.proStatusManager = proStatusManager
    }

    var body: some View {
        KikiPaywallShell(
            width: 520,
            height: 620,
            horizontalPadding: 28,
            tint: .orange
        ) {
            KikiPaywallHeader(
                title: config.appName,
                subtitle: headerSubtitle
            )
        } content: {
            HStack(spacing: 12) {
                ForEach(config.stats, id: \.label) { stat in
                    KikiPaywallStatItem(value: stat.value, label: stat.label, tint: .orange)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(config.features, id: \.self) { feature in
                    KikiPaywallFeatureRow(icon: "checkmark.circle", text: feature, tint: .orange)
                }
            }

            HStack(spacing: 12) {
                ForEach(proStatusManager.availablePlans) { product in
                    KikiPaywallPlanCard(
                        plan: product.kikiPaywallPlan,
                        isSelected: selectedPlan == product.plan,
                        tint: .orange,
                        onSelect: { selectedPlan = product.plan }
                    )
                }
            }

            Text("Both one-time purchases unlock the same Pro features. Choose the price that feels right.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            messageStack
        } actions: {
            actionStack
        } footer: {
            EmptyView()
        }
        .task {
            await loadOfferings()
        }
        .onChange(of: proStatusManager.availablePlans) { _ in
            syncSelectedPlan()
        }
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

    private var headerSubtitle: String {
        switch proStatusManager.status {
        case .pro:
            return "Pro is active. Thank you for supporting Cat Keyboard Lock."
        case .trial(let daysRemaining, let expiresAt):
            return "\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left in your Pro trial, expires \(formattedDate(expiresAt))."
        case .notStarted:
            return "Protect your Mac from curious paws with a 2-day Pro trial."
        case .expired:
            return "Your trial has ended. Upgrade to keep locking input."
        }
    }

    private var messageStack: some View {
        VStack(spacing: 6) {
            if isLoadingOfferings {
                Text("Loading purchase options...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let paywallErrorMessage = proStatusManager.paywallErrorMessage {
                Text(paywallErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let successMessage = proStatusManager.paywallSuccessMessage {
                Text(successMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var actionStack: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchaseSelectedPlan() }
            } label: {
                KikiPaywallActionLabel(
                    title: purchaseCTA,
                    isLoading: proStatusManager.purchaseInProgressPlan == selectedPlan,
                    isProminent: true,
                    tint: .orange
                )
            }
            .buttonStyle(.plain)
            .disabled(proStatusManager.status.isPro || isBusy || !selectedProduct.isAvailable)

            if proStatusManager.status.canStartTrial {
                Button {
                    Task { await startTrial() }
                } label: {
                    KikiPaywallActionLabel(
                        title: "Start 2-Day Pro Trial",
                        isLoading: isStartingTrial,
                        isProminent: false,
                        tint: .orange
                    )
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }

            Button {
                Task { await restorePurchases() }
            } label: {
                KikiPaywallActionLabel(
                    title: proStatusManager.isRestoringPurchases ? "Restoring..." : "Restore Purchase",
                    isLoading: proStatusManager.isRestoringPurchases,
                    isProminent: false,
                    tint: .orange
                )
            }
            .buttonStyle(.plain)
            .disabled(proStatusManager.status.isPro || isBusy)
        }
    }

    private var purchaseCTA: String {
        guard selectedProduct.isAvailable else {
            return "Unavailable"
        }

        if proStatusManager.status.isPro {
            return "Already Pro"
        }

        return "Unlock Forever - \(selectedProduct.displayPrice)"
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

    private func purchaseSelectedPlan() async {
        guard selectedProduct.isAvailable else {
            return
        }

        do {
            try await proStatusManager.purchase(selectedPlan)
        } catch {
            // User-facing error state is owned by the status manager.
        }
    }

    private func startTrial() async {
        isStartingTrial = true
        await proStatusManager.startTrial()
        isStartingTrial = false
    }

    private func restorePurchases() async {
        do {
            try await proStatusManager.restorePurchases()
        } catch {
            // User-facing error state is owned by the status manager.
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
