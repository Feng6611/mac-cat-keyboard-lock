import Foundation
import RevenueCatCommerceKit

enum CatKeyboardLockRevenueCatConfiguration {
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
            logSubsystem: Bundle.main.bundleIdentifier ?? "dev.kkuk.catkeyboardlock",
            logCategory: "Purchase"
        )
    }
}
