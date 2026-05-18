import Foundation

struct CatKeyboardLockEntitlementSnapshot: Equatable {
    let status: CatKeyboardLockProStatus

    init(status: CatKeyboardLockProStatus) {
        self.status = status
    }

    init(isPro: Bool, isTrialActive: Bool) {
        if isPro {
            self.status = .pro(plan: .supporterLifetime, originalPurchaseDate: nil)
        } else if isTrialActive {
            self.status = .trial(daysRemaining: 2, expiresAt: .distantFuture)
        } else {
            self.status = .expired
        }
    }

    var isPro: Bool {
        status.isPro
    }

    var isTrialActive: Bool {
        status.isTrial
    }

    var isAccessActive: Bool {
        status.isActive
    }

    var canStartTrial: Bool {
        status.canStartTrial
    }

    var displayName: String {
        status.displayName
    }
}
