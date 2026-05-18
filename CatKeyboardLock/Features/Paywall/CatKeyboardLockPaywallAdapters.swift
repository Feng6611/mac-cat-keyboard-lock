import KikiPaywall

extension CatKeyboardLockPlanConfig {
    var kikiPaywallPlan: KikiPaywallPlan {
        KikiPaywallPlan(
            id: id,
            title: title,
            displayPrice: displayPrice,
            originalPrice: originalPrice,
            billingDetail: billingDetail,
            badge: badge
        )
    }
}

extension CatKeyboardLockProPlanProduct {
    var kikiPaywallPlan: KikiPaywallPlan {
        KikiPaywallPlan(
            id: plan.id,
            title: title,
            displayPrice: displayPrice,
            originalPrice: nil,
            billingDetail: billingDetail,
            badge: badge,
            isAvailable: isAvailable
        )
    }
}
