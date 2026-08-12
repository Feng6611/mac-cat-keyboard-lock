import Foundation

struct CatKeyboardLockAppConfig: Equatable {
    let appName: String
    let statusItemTitle: String
    let bundleID: String
    let repositoryURL: String
    let madeByName: String
    let madeByURL: String
    let contactEmailAddress: String
    let features: [String]

    static let `default` = CatKeyboardLockAppConfig(
        appName: "Cat Keyboard Lock",
        statusItemTitle: "Cat Lock",
        bundleID: "dev.kkuk.catkeyboardlock",
        repositoryURL: "https://github.com/Feng6611/mac-cat-keyboard-lock",
        madeByName: "chenfeng",
        madeByURL: "https://github.com/Feng6611",
        contactEmailAddress: "fchen6611@gmail.com",
        features: [
            "Keyboard lock",
            "Trigger corner and lock feedback controls",
            "Lock duration safety release"
        ]
    )
}
