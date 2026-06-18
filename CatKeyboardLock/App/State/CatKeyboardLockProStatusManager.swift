import Combine
import Foundation
import KikiCommerce
import RevenueCatCommerceKit

@MainActor
final class CatKeyboardLockProStatusManager: ObservableObject {
    enum Constants {
        static let trialDuration = CatKeyboardLockRevenueCatConfiguration.trialDuration
        static let transactionRefreshAttempts = KikiProAccessManager.Constants.transactionRefreshAttempts
        static let transactionRefreshDelayNanoseconds = KikiProAccessManager.Constants.transactionRefreshDelayNanoseconds
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

    let kikiProAccessManager: KikiProAccessManager

    private var cancellables: Set<AnyCancellable> = []

    var snapshot: CatKeyboardLockEntitlementSnapshot {
        CatKeyboardLockEntitlementSnapshot(status: status)
    }

    var hasCompletedOnboarding: Bool {
        kikiProAccessManager.hasCompletedOnboarding
    }

    var shouldShowOnboarding: Bool {
        kikiProAccessManager.shouldShowOnboarding
    }

    var currentEntitlementSnapshot: CommerceEntitlement? {
        kikiProAccessManager.currentEntitlementSnapshot
    }

    init(
        defaults: UserDefaults = .standard,
        commerceClient: (any CommerceClient)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        let manager = KikiProAccessManager(
            configuration: CatKeyboardLockRevenueCatConfiguration.proAccessConfiguration,
            defaults: defaults,
            commerceClient: commerceClient,
            now: now
        )

        self.kikiProAccessManager = manager
        self.status = CatKeyboardLockProStatus(kikiStatus: manager.status)
        self.availablePlans = manager.availablePlans.compactMap(CatKeyboardLockProPlanProduct.init(kikiProduct:))
        self.lastError = manager.lastError
        self.purchaseInProgressPlan = nil
        self.isRestoringPurchases = manager.isRestoringPurchases
        self.paywallErrorMessage = manager.paywallErrorMessage
        self.paywallSuccessMessage = manager.paywallSuccessMessage
#if DEBUG
        self.debugProAccessOverride = manager.debugProAccessOverride
#endif

        bindManager()
    }

    func configureIfNeeded() {
        kikiProAccessManager.configureIfNeeded()
    }

    func refresh() async {
        await kikiProAccessManager.refresh()
    }

    func loadOfferings() async {
        await kikiProAccessManager.loadOfferings()
    }

    func startTrial() async {
        await kikiProAccessManager.startTrial()
    }

    func completeOnboardingWithoutTrial() {
        kikiProAccessManager.completeOnboardingWithoutTrial()
    }

#if DEBUG
    var debugProAccessToggleIsOn: Bool {
        kikiProAccessManager.debugProAccessToggleIsOn
    }

    var debugProAccessOverrideDisplayName: String {
        kikiProAccessManager.debugProAccessOverrideDisplayName
    }

    func setDebugProAccessOverride(_ isPro: Bool) {
        kikiProAccessManager.setDebugProAccessOverride(isPro)
    }

    func toggleDebugProAccessOverride() {
        setDebugProAccessOverride(!debugProAccessToggleIsOn)
    }

    func clearDebugProAccessOverride() {
        kikiProAccessManager.clearDebugProAccessOverride()
    }
#endif

    func purchase(_ plan: CatKeyboardLockPurchasePlan) async throws {
        try await kikiProAccessManager.purchase(planID: plan.id)
    }

    func restorePurchases() async throws {
        try await kikiProAccessManager.restorePurchases()
    }

    func planProduct(for plan: CatKeyboardLockPurchasePlan) -> CatKeyboardLockProPlanProduct {
        availablePlans.first(where: { $0.plan == plan }) ?? .fallback(for: plan)
    }

    static func makeAvailablePlans(
        packageMetadata: [CatKeyboardLockPurchasePlan: CatKeyboardLockProPlanPackageMetadata]?,
        offeringsAttempted: Bool = false
    ) -> [CatKeyboardLockProPlanProduct] {
        let metadata = packageMetadata?.reduce(into: [String: KikiProPlanPackageMetadata]()) { result, item in
            result[item.key.id] = KikiProPlanPackageMetadata(
                displayPrice: item.value.displayPrice,
                billingDetail: item.value.billingDetail,
                isAvailable: item.value.isAvailable
            )
        }

        return KikiProAccessManager
            .makeAvailablePlans(
                plans: CatKeyboardLockPurchasePlan.allCases.map(\.kikiProPlan),
                packageMetadata: metadata,
                offeringsAttempted: offeringsAttempted
            )
            .compactMap(CatKeyboardLockProPlanProduct.init(kikiProduct:))
    }

    private func bindManager() {
        kikiProAccessManager.$status
            .map(CatKeyboardLockProStatus.init(kikiStatus:))
            .sink { [weak self] status in
                self?.status = status
            }
            .store(in: &cancellables)

        kikiProAccessManager.$availablePlans
            .map { $0.compactMap(CatKeyboardLockProPlanProduct.init(kikiProduct:)) }
            .sink { [weak self] availablePlans in
                self?.availablePlans = availablePlans
            }
            .store(in: &cancellables)

        kikiProAccessManager.$lastError
            .sink { [weak self] lastError in
                self?.lastError = lastError
            }
            .store(in: &cancellables)

        kikiProAccessManager.$purchaseInProgressPlanID
            .map { planID in
                planID.flatMap(CatKeyboardLockPurchasePlan.init(rawValue:))
            }
            .sink { [weak self] purchaseInProgressPlan in
                self?.purchaseInProgressPlan = purchaseInProgressPlan
            }
            .store(in: &cancellables)

        kikiProAccessManager.$isRestoringPurchases
            .sink { [weak self] isRestoringPurchases in
                self?.isRestoringPurchases = isRestoringPurchases
            }
            .store(in: &cancellables)

        kikiProAccessManager.$paywallErrorMessage
            .sink { [weak self] paywallErrorMessage in
                self?.paywallErrorMessage = paywallErrorMessage
            }
            .store(in: &cancellables)

        kikiProAccessManager.$paywallSuccessMessage
            .sink { [weak self] paywallSuccessMessage in
                self?.paywallSuccessMessage = paywallSuccessMessage
            }
            .store(in: &cancellables)

#if DEBUG
        kikiProAccessManager.$debugProAccessOverride
            .sink { [weak self] debugProAccessOverride in
                self?.debugProAccessOverride = debugProAccessOverride
            }
            .store(in: &cancellables)
#endif
    }
}
