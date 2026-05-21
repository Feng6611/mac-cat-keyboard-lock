import Combine
import Foundation
import RevenueCatCommerceKit

@MainActor
final class CatKeyboardLockProStatusManager: ObservableObject {
    enum Constants {
        static let trialDuration: TimeInterval = 2 * 24 * 60 * 60
        static let transactionRefreshAttempts = 3
        static let transactionRefreshDelayNanoseconds: UInt64 = 750_000_000
    }

    @Published private(set) var status: CatKeyboardLockProStatus
    @Published private(set) var availablePlans: [CatKeyboardLockProPlanProduct]
    @Published private(set) var lastError: CommercePurchaseError?
    @Published private(set) var purchaseInProgressPlan: CatKeyboardLockPurchasePlan?
    @Published private(set) var isRestoringPurchases = false
    @Published private(set) var paywallErrorMessage: String?
    @Published private(set) var paywallSuccessMessage: String?
#if DEBUG
    @Published private(set) var debugProAccessOverride: Bool?
#endif

    private let defaults: UserDefaults
    private let commerceClient: any CommerceClient
    private let now: () -> Date

    private var entitlementSnapshot: CommerceEntitlement?
    private var currentOffering: CommerceOffering?
    private var hasConfigured = false
    private var expirationTask: Task<Void, Never>?

    var snapshot: CatKeyboardLockEntitlementSnapshot {
        CatKeyboardLockEntitlementSnapshot(status: status)
    }

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: CatKeyboardLockProDefaults.Keys.hasCompletedOnboarding)
    }

    var shouldShowOnboarding: Bool {
#if DEBUG
        if debugProAccessOverride != nil {
            return false
        }
#endif

        return !hasCompletedOnboarding && !status.isPro
    }

    var currentEntitlementSnapshot: CommerceEntitlement? {
        entitlementSnapshot
    }

    init(
        defaults: UserDefaults = .standard,
        commerceClient: (any CommerceClient)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        let client = commerceClient ?? RevenueCatCommerceClient(
            configuration: CatKeyboardLockRevenueCatConfiguration.commerceConfiguration
        )
        let cachedSnapshot = client.cachedEntitlement

        self.defaults = defaults
        self.commerceClient = client
        self.now = now
        self.entitlementSnapshot = cachedSnapshot
        self.currentOffering = nil
        self.availablePlans = CatKeyboardLockProPlanProduct.fallbackPlans
        self.lastError = nil
        self.purchaseInProgressPlan = nil
        self.paywallErrorMessage = nil
        self.paywallSuccessMessage = nil
#if DEBUG
        self.debugProAccessOverride = Self.readDebugProAccessOverride(defaults: defaults)
#endif
        self.status = Self.computeStatus(entitlementSnapshot: cachedSnapshot, defaults: defaults, now: now)
        scheduleExpirationIfNeeded()
    }

    deinit {
        expirationTask?.cancel()
    }

    func configureIfNeeded() {
        guard !hasConfigured else {
            return
        }

        commerceClient.entitlementDidChange = { [weak self] snapshot in
            self?.entitlementSnapshot = snapshot
            self?.applyStatus(self?.computeStatus() ?? .expired)
        }
        commerceClient.configureIfNeeded()
        entitlementSnapshot = commerceClient.cachedEntitlement
        hasConfigured = true
        applyStatus(computeStatus())
    }

    func refresh() async {
        configureIfNeeded()

        do {
            entitlementSnapshot = try await commerceClient.refreshEntitlement()
            lastError = nil
        } catch {
            lastError = CommercePurchaseError(error: error)
        }

        applyStatus(computeStatus())
    }

    func loadOfferings() async {
        configureIfNeeded()

        if let currentOffering {
            availablePlans = Self.resolveAvailablePlans(offering: currentOffering, offeringsError: nil)
            return
        }

        var offeringsError: Error?
        do {
            currentOffering = try await commerceClient.loadOffering()
        } catch {
            currentOffering = nil
            offeringsError = error
        }

        availablePlans = Self.resolveAvailablePlans(offering: currentOffering, offeringsError: offeringsError)
    }

    func startTrial() async {
        clearPaywallMessages()
        guard status.canStartTrial else {
            return
        }

        let resolvedStartDate = now()
        defaults.set(resolvedStartDate, forKey: CatKeyboardLockProDefaults.Keys.trialStartedAt)
        defaults.set(true, forKey: CatKeyboardLockProDefaults.Keys.hasCompletedOnboarding)
        applyStatus(computeStatus())
    }

    func completeOnboardingWithoutTrial() {
        defaults.set(true, forKey: CatKeyboardLockProDefaults.Keys.hasCompletedOnboarding)
    }

#if DEBUG
    var debugProAccessToggleIsOn: Bool {
        debugProAccessOverride ?? status.isPro
    }

    var debugProAccessOverrideDisplayName: String {
        guard let debugProAccessOverride else {
            return "Off"
        }

        return debugProAccessOverride ? "Paid" : "Unpaid"
    }

    func setDebugProAccessOverride(_ isPro: Bool) {
        defaults.set(isPro, forKey: CatKeyboardLockProDefaults.Keys.debugProAccessOverride)
        defaults.set(true, forKey: CatKeyboardLockProDefaults.Keys.hasCompletedOnboarding)
        debugProAccessOverride = isPro
        clearPaywallMessages()
        applyStatus(computeStatus())
    }

    func toggleDebugProAccessOverride() {
        setDebugProAccessOverride(!debugProAccessToggleIsOn)
    }

    func clearDebugProAccessOverride() {
        defaults.removeObject(forKey: CatKeyboardLockProDefaults.Keys.debugProAccessOverride)
        debugProAccessOverride = nil
        clearPaywallMessages()
        applyStatus(computeStatus())
    }
#endif

    func purchase(_ plan: CatKeyboardLockPurchasePlan) async throws {
        configureIfNeeded()
        clearPaywallMessages()
        purchaseInProgressPlan = plan
        defer { purchaseInProgressPlan = nil }

        do {
            let snapshot = try await commerceClient.purchase(plan.commercePlan)
            lastError = nil
            entitlementSnapshot = snapshot
            applyStatus(computeStatus())

            if !status.isPro {
                let didUnlock = await refreshEntitlementStateAfterTransaction()
                if !didUnlock {
                    throw CommercePurchaseError.activationPending
                }
            }

            if status.isPro {
                defaults.set(true, forKey: CatKeyboardLockProDefaults.Keys.hasCompletedOnboarding)
                paywallSuccessMessage = "Purchase successful. Pro unlocked."
            }
        } catch {
            let purchaseError = CommercePurchaseError(error: error)
            lastError = purchaseError
            paywallErrorMessage = purchaseError == .purchaseCancelled ? nil : purchaseError.errorDescription
            paywallSuccessMessage = nil
            throw purchaseError
        }
    }

    func restorePurchases() async throws {
        configureIfNeeded()
        clearPaywallMessages()
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            let snapshot = try await commerceClient.restorePurchases()
            lastError = nil
            entitlementSnapshot = snapshot
            applyStatus(computeStatus())

            if !status.isPro {
                if snapshot != nil {
                    let didUnlock = await refreshEntitlementStateAfterTransaction()
                    if !didUnlock {
                        throw CommercePurchaseError.activationPending
                    }
                } else {
                    paywallErrorMessage = "No active purchase found on this account."
                }
            }

            if status.isPro {
                defaults.set(true, forKey: CatKeyboardLockProDefaults.Keys.hasCompletedOnboarding)
                paywallSuccessMessage = "Purchase restored."
            }
        } catch {
            let purchaseError = CommercePurchaseError(error: error)
            lastError = purchaseError
            paywallErrorMessage = purchaseError == .purchaseCancelled ? nil : purchaseError.errorDescription
            paywallSuccessMessage = nil
            throw purchaseError
        }
    }

    func planProduct(for plan: CatKeyboardLockPurchasePlan) -> CatKeyboardLockProPlanProduct {
        availablePlans.first(where: { $0.plan == plan }) ?? .fallback(for: plan)
    }

    static func makeAvailablePlans(
        packageMetadata: [CatKeyboardLockPurchasePlan: CatKeyboardLockProPlanPackageMetadata]?,
        offeringsAttempted: Bool = false
    ) -> [CatKeyboardLockProPlanProduct] {
        CatKeyboardLockPurchasePlan.allCases.map { plan in
            let fallback = CatKeyboardLockProPlanProduct.fallback(
                for: plan,
                isAvailable: packageMetadata == nil && !offeringsAttempted
            )

            guard let metadata = packageMetadata?[plan] else {
                return fallback
            }

            return CatKeyboardLockProPlanProduct(
                plan: plan,
                title: fallback.title,
                displayPrice: metadata.displayPrice,
                billingDetail: metadata.billingDetail,
                badge: fallback.badge,
                isAvailable: metadata.isAvailable
            )
        }
    }

    private func clearPaywallMessages() {
        paywallErrorMessage = nil
        paywallSuccessMessage = nil
    }

    private func refreshEntitlementStateAfterTransaction() async -> Bool {
        for attempt in 1...Constants.transactionRefreshAttempts {
            do {
                entitlementSnapshot = try await commerceClient.refreshEntitlement()
                applyStatus(computeStatus())

                if status.isPro {
                    return true
                }
            } catch {
                lastError = CommercePurchaseError(error: error)
            }

            if attempt < Constants.transactionRefreshAttempts {
                try? await Task.sleep(nanoseconds: Constants.transactionRefreshDelayNanoseconds)
            }
        }

        return false
    }

    private func computeStatus() -> CatKeyboardLockProStatus {
        Self.computeStatus(entitlementSnapshot: entitlementSnapshot, defaults: defaults, now: now)
    }

    private func applyStatus(_ newStatus: CatKeyboardLockProStatus) {
        status = newStatus
        scheduleExpirationIfNeeded()
    }

    private func scheduleExpirationIfNeeded() {
        expirationTask?.cancel()
        expirationTask = nil

        guard case .trial(_, let expiresAt) = status else {
            return
        }

        let delay = max(0, expiresAt.timeIntervalSince(now()))
        let nanoseconds = UInt64(delay * 1_000_000_000)
        expirationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled, let self else {
                return
            }
            self.applyStatus(self.computeStatus())
        }
    }

    private static func computeStatus(
        entitlementSnapshot: CommerceEntitlement?,
        defaults: UserDefaults,
        now: () -> Date
    ) -> CatKeyboardLockProStatus {
#if DEBUG
        if let debugProAccessOverride = readDebugProAccessOverride(defaults: defaults) {
            return debugProAccessOverride
                ? .pro(plan: .supporterLifetime, originalPurchaseDate: nil)
                : .expired
        }
#endif

        if let entitlementSnapshot,
           let plan = CatKeyboardLockPurchasePlan(commercePlan: entitlementSnapshot.plan) {
            return .pro(plan: plan, originalPurchaseDate: entitlementSnapshot.originalPurchaseDate)
        }

        guard let trialStartedAt = defaults.object(forKey: CatKeyboardLockProDefaults.Keys.trialStartedAt) as? Date else {
            return .notStarted
        }

        let expiresAt = trialStartedAt.addingTimeInterval(Constants.trialDuration)
        let remaining = expiresAt.timeIntervalSince(now())

        if remaining > 0 {
            let daysRemaining = max(1, Int(ceil(remaining / 86_400)))
            return .trial(daysRemaining: daysRemaining, expiresAt: expiresAt)
        }

        return .expired
    }

#if DEBUG
    private static func readDebugProAccessOverride(defaults: UserDefaults) -> Bool? {
        guard defaults.object(forKey: CatKeyboardLockProDefaults.Keys.debugProAccessOverride) != nil else {
            return nil
        }

        return defaults.bool(forKey: CatKeyboardLockProDefaults.Keys.debugProAccessOverride)
    }
#endif

    private static func packageMetadata(from offering: CommerceOffering?) -> [CatKeyboardLockPurchasePlan: CatKeyboardLockProPlanPackageMetadata]? {
        guard let offering, !offering.isEmpty else {
            return nil
        }

        return Dictionary(uniqueKeysWithValues: offering.products.compactMap { product in
            guard let plan = CatKeyboardLockPurchasePlan(commercePlan: product.plan) else {
                return nil
            }

            return (
                plan,
                CatKeyboardLockProPlanPackageMetadata(
                    displayPrice: product.displayPrice,
                    billingDetail: plan.billingDetail,
                    isAvailable: product.isAvailable
                )
            )
        })
    }

    private static func resolveAvailablePlans(
        offering: CommerceOffering?,
        offeringsError: Error?
    ) -> [CatKeyboardLockProPlanProduct] {
        let purchaseError = offeringsError.map(CommercePurchaseError.init(error:))
        let shouldKeepFallbackAvailable = purchaseError == .network

        return makeAvailablePlans(
            packageMetadata: packageMetadata(from: offering),
            offeringsAttempted: !shouldKeepFallbackAvailable
        )
    }
}
