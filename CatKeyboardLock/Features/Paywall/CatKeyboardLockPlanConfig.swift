import Foundation

struct CatKeyboardLockPlanConfig: Equatable, Identifiable {
    let purchasePlan: CatKeyboardLockPurchasePlan
    let title: String
    let displayPrice: String
    let originalPrice: String?
    let billingDetail: String
    let badge: String?

    var id: String {
        purchasePlan.id
    }
}
