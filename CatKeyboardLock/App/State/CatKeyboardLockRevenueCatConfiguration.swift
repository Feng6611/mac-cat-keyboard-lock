import Foundation
import KikiCommerceCore
import KikiRevenueCat

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
            entitlementIdentifier: entitlementIdentifier,
            productIdentifiers: [
                CatKeyboardLockPurchasePlan.lifetime.commercePlan: lifetimeProductIdentifier,
                CatKeyboardLockPurchasePlan.supporterLifetime.commercePlan: supporterProductIdentifier
            ],
            entitlementMatchingPolicy: .configuredEntitlementOrProductOnly,
            logSubsystem: Bundle.main.bundleIdentifier ?? "dev.kkuk.catkeyboardlock",
            logCategory: "Purchase"
        )
    }

    static var revenueCatConfiguration: RevenueCatConfiguration {
        RevenueCatConfiguration.standardPro(
            apiKey: apiKey,
            offeringIdentifier: offeringIdentifier
        )
    }

    static var accessConfiguration: KikiAccessConfiguration {
        KikiAccessConfiguration(
            plans: CatKeyboardLockPurchasePlan.allCases.map(\.kikiAccessPlan),
            defaultPlanID: CatKeyboardLockPurchasePlan.defaultSelection.id,
            commerceConfiguration: commerceConfiguration,
            trialPolicy: .autoStart(duration: trialDuration),
            storageKeys: KikiAccessStorageKeys(
                trialStartedAt: CatKeyboardLockProDefaults.Keys.trialStartedAt,
                debugProAccessOverride: CatKeyboardLockProDefaults.Keys.debugProAccessOverride,
                usageCountPrefix: CatKeyboardLockProDefaults.Keys.usageCountPrefix
            )
        )
    }
}
