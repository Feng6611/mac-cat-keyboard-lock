import Foundation
import KikiCommerce
import RevenueCatCommerceKit

enum CatKeyboardLockRevenueCatConfiguration {
    static let trialDuration: TimeInterval = 2 * 24 * 60 * 60

    static let apiKeyInfoKey = "CatKeyboardLockRevenueCatAPIKey"
    static let entitlementIdentifier = "cat keyboard lock Pro"
    static let offeringIdentifier = "default"
    static let lifetimeProductIdentifier = "dev.kkuk.catkeyboardlock.pro.lifetime"
    static let supporterProductIdentifier = "dev.kkuk.catkeyboardlock.pro.supporter"

    static var apiKey: String {
        let configuredKey = (Bundle.main.object(forInfoDictionaryKey: apiKeyInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return configuredKey ?? ""
    }

    static var commerceConfiguration: CommerceConfiguration {
        CommerceConfiguration(
            apiKey: apiKey,
            entitlementIdentifier: entitlementIdentifier,
            offeringIdentifier: offeringIdentifier,
            productIdentifiers: [
                CatKeyboardLockPurchasePlan.lifetime.commercePlan: lifetimeProductIdentifier,
                CatKeyboardLockPurchasePlan.supporterLifetime.commercePlan: supporterProductIdentifier
            ],
            entitlementMatchingPolicy: .configuredEntitlementOrProductOnly,
            logSubsystem: Bundle.main.bundleIdentifier ?? "dev.kkuk.catkeyboardlock",
            logCategory: "Purchase"
        )
    }

    static var proAccessConfiguration: KikiProAccessConfiguration {
        KikiProAccessConfiguration(
            plans: CatKeyboardLockPurchasePlan.allCases.map(\.kikiProPlan),
            defaultPlanID: CatKeyboardLockPurchasePlan.defaultSelection.id,
            commerceConfiguration: commerceConfiguration,
            trialPolicy: .explicitStart(duration: trialDuration),
            storageKeys: KikiProAccessStorageKeys(
                trialStartedAt: CatKeyboardLockProDefaults.Keys.trialStartedAt,
                hasCompletedOnboarding: CatKeyboardLockProDefaults.Keys.hasCompletedOnboarding,
                debugProAccessOverride: CatKeyboardLockProDefaults.Keys.debugProAccessOverride
            )
        )
    }
}
