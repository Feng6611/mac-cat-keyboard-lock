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
