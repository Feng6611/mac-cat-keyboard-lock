import Foundation

struct CatKeyboardLockAppConfig: Equatable {
    let appName: String
    let statusItemTitle: String
    let supportURL: String
    let privacyURL: String
    let repositoryURL: String
    let plans: [CatKeyboardLockPlanConfig]
    let features: [String]
    let stats: [CatKeyboardLockStatConfig]

    static let `default` = CatKeyboardLockAppConfig(
        appName: "Cat Keyboard Lock",
        statusItemTitle: "Cat Lock",
        supportURL: "https://github.com/Feng6611/Kiki_mackit",
        privacyURL: "https://example.com/privacy",
        repositoryURL: "https://github.com/Feng6611/mac-cat-keyboard-lock",
        plans: [
            CatKeyboardLockPlanConfig(
                purchasePlan: .lifetime,
                title: "Lifetime",
                displayPrice: "$5.99",
                originalPrice: nil,
                billingDetail: "one-time purchase",
                badge: nil
            ),
            CatKeyboardLockPlanConfig(
                purchasePlan: .supporterLifetime,
                title: "Supporter Lifetime",
                displayPrice: "$10.99",
                originalPrice: nil,
                billingDetail: "one-time purchase",
                badge: "Recommended"
            )
        ],
        features: [
            "Full keyboard, click, and movement lock",
            "Trigger corner and lock feedback controls",
            "Lock duration safety release"
        ],
        stats: [
            CatKeyboardLockStatConfig(value: "2 days", label: "free trial"),
            CatKeyboardLockStatConfig(value: "1s", label: "shortcut hold")
        ]
    )
}
