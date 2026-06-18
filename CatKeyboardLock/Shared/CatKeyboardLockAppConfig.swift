import Foundation

struct CatKeyboardLockAppConfig: Equatable {
    let appName: String
    let statusItemTitle: String
    let bundleID: String
    let officialURL: String
    let officialDisplayName: String
    let termsURL: String
    let supportURL: String
    let privacyURL: String
    let repositoryURL: String
    let repositoryDisplayName: String
    let contactEmailAddress: String
    let contactEmailURL: String
    let plans: [CatKeyboardLockPlanConfig]
    let features: [String]
    let stats: [CatKeyboardLockStatConfig]

    static let `default` = CatKeyboardLockAppConfig(
        appName: "Cat Keyboard Lock",
        statusItemTitle: "Cat Lock",
        bundleID: "dev.kkuk.catkeyboardlock",
        officialURL: "https://github.com/Feng6611/mac-cat-keyboard-lock#readme",
        officialDisplayName: "GitHub README",
        termsURL: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/",
        supportURL: "https://github.com/Feng6611/mac-cat-keyboard-lock/issues",
        privacyURL: "https://github.com/Feng6611/mac-cat-keyboard-lock/blob/main/PRIVACY.md",
        repositoryURL: "https://github.com/Feng6611/mac-cat-keyboard-lock",
        repositoryDisplayName: "Feng6611/mac-cat-keyboard-lock",
        contactEmailAddress: "fchen6611@gmail.com",
        contactEmailURL: "mailto:fchen6611@gmail.com",
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
            "Full keyboard and click lock",
            "Trigger corner and lock feedback controls",
            "Lock duration safety release"
        ],
        stats: [
            CatKeyboardLockStatConfig(value: "2 days", label: "free trial"),
            CatKeyboardLockStatConfig(value: "1s", label: "shortcut hold")
        ]
    )
}
