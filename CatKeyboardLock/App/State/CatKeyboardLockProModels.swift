import Foundation
import RevenueCatCommerceKit

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
        switch self {
        case .lifetime:
            return .yearly
        case .supporterLifetime:
            return .lifetime
        }
    }

    init?(commercePlan: CommercePlan) {
        switch commercePlan {
        case .yearly:
            self = .lifetime
        case .lifetime:
            self = .supporterLifetime
        }
    }
}

enum CatKeyboardLockProStatus: Equatable {
    case notStarted
    case trial(daysRemaining: Int, expiresAt: Date)
    case expired
    case pro(plan: CatKeyboardLockPurchasePlan, originalPurchaseDate: Date?)

    var isActive: Bool {
        switch self {
        case .trial, .pro:
            return true
        case .notStarted, .expired:
            return false
        }
    }

    var isPro: Bool {
        if case .pro = self {
            return true
        }
        return false
    }

    var isTrial: Bool {
        if case .trial = self {
            return true
        }
        return false
    }

    var canStartTrial: Bool {
        if case .notStarted = self {
            return true
        }
        return false
    }

    var displayName: String {
        switch self {
        case .notStarted:
            return "Trial not started"
        case .trial(let daysRemaining, _):
            return "\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left"
        case .expired:
            return "Trial ended"
        case .pro:
            return "Pro"
        }
    }
}

struct CatKeyboardLockProPlanPackageMetadata: Equatable {
    let displayPrice: String
    let billingDetail: String
    let isAvailable: Bool
}

struct CatKeyboardLockProPlanProduct: Equatable, Identifiable {
    let plan: CatKeyboardLockPurchasePlan
    let title: String
    let displayPrice: String
    let billingDetail: String
    let badge: String?
    let isAvailable: Bool

    var id: CatKeyboardLockPurchasePlan { plan }

    static func fallback(for plan: CatKeyboardLockPurchasePlan, isAvailable: Bool = true) -> Self {
        Self(
            plan: plan,
            title: plan.title,
            displayPrice: plan.fallbackDisplayPrice,
            billingDetail: plan.billingDetail,
            badge: plan.badge,
            isAvailable: isAvailable
        )
    }

    static let fallbackPlans: [Self] = CatKeyboardLockPurchasePlan.allCases.map {
        .fallback(for: $0)
    }
}

enum CatKeyboardLockProDefaults {
    enum Keys {
        static let trialStartedAt = "CatKeyboardLock.Pro.trialStartedAt"
        static let hasCompletedOnboarding = "CatKeyboardLock.Pro.hasCompletedOnboarding"
#if DEBUG
        static let debugProAccessOverride = "CatKeyboardLock.Pro.debugProAccessOverride"
#endif
    }
}
