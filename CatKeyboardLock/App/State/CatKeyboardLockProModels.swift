import Foundation
import KikiCommerceCore

enum CatKeyboardLockPurchasePlan: String, CaseIterable, Equatable, Hashable, Identifiable {
    case lifetime
    case supporterLifetime

    static let defaultSelection: Self = .supporterLifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lifetime:
            return "Lifetime"
        case .supporterLifetime:
            return "Supporter Lifetime"
        }
    }

    var fallbackDisplayPrice: String {
        switch self {
        case .lifetime:
            return "$5.99"
        case .supporterLifetime:
            return "$10.99"
        }
    }

    var billingDetail: String {
        "one-time purchase"
    }

    var badge: String? {
        switch self {
        case .lifetime:
            return nil
        case .supporterLifetime:
            return "Recommended"
        }
    }

    var commercePlan: CommercePlan {
        CommercePlan(rawValue)
    }

    init?(commercePlan: CommercePlan) {
        self.init(rawValue: commercePlan.rawValue)
    }

    var kikiProPlan: KikiProPlan {
        KikiProPlan(
            id: id,
            commercePlan: commercePlan,
            title: title,
            fallbackDisplayPrice: fallbackDisplayPrice,
            billingDetail: billingDetail,
            subtitle: "All Cat Keyboard Lock Pro features",
            badge: badge
        )
    }
}

struct CatKeyboardLockProPlanPackageMetadata: Equatable {
    let displayPrice: String
    let billingDetail: String
    let isAvailable: Bool
}

enum CatKeyboardLockProDefaults {
    enum Keys {
        static let trialStartedAt = "CatKeyboardLock.Pro.trialStartedAt"
        static let debugProAccessOverride = "CatKeyboardLock.Pro.debugProAccessOverride"
        static let usageCountPrefix = "CatKeyboardLock.Pro.usage"
    }
}
