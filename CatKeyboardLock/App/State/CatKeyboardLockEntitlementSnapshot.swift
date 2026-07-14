import Foundation
import KikiCommerceCore

struct CatKeyboardLockEntitlementSnapshot: Equatable {
    let status: KikiAccessState

    init(status: KikiAccessState) {
        self.status = status
    }

    init(isPro: Bool, isTrialActive: Bool) {
        if isPro {
            self.status = .pro(
                plan: CatKeyboardLockPurchasePlan.lifetime.kikiAccessPlan,
                entitlement: CommerceEntitlement(
                    plan: .lifetime,
                    productIdentifier: CatKeyboardLockRevenueCatConfiguration.lifetimeProductIdentifier,
                    entitlementIdentifier: CatKeyboardLockRevenueCatConfiguration.entitlementIdentifier,
                    expirationDate: nil,
                    originalPurchaseDate: nil
                )
            )
        } else if isTrialActive {
            self.status = .trial(
                .time(daysRemaining: 2, expiresAt: .distantFuture)
            )
        } else {
            self.status = .expired
        }
    }

    var isPro: Bool {
        status.isPro
    }

    var isTrialActive: Bool {
        if case .trial = status {
            return true
        }
        return false
    }

    var isAccessActive: Bool {
        status.isActive
    }

    var canStartTrial: Bool {
        status.canStartTrial
    }

}
