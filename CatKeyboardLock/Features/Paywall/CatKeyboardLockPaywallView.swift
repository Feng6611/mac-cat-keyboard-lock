import AppKit
import KikiCommerceCore
import KikiCommercePresentation
import SwiftUI

enum CatKeyboardLockPaywallContext {
    case settings
    case onboarding

    var kikiContext: KikiProPaywallPresentationContext {
        switch self {
        case .settings:
            return .settings
        case .onboarding:
            return .onboarding
        }
    }
}

struct CatKeyboardLockPaywallSheetView: View {
    let config: CatKeyboardLockAppConfig
    @ObservedObject var accessManager: KikiProAccessManager
    let context: CatKeyboardLockPaywallContext
    let onFinish: (() -> Void)?

    init(
        config: CatKeyboardLockAppConfig,
        accessManager: KikiProAccessManager,
        context: CatKeyboardLockPaywallContext,
        onFinish: (() -> Void)? = nil
    ) {
        self.config = config
        self.accessManager = accessManager
        self.context = context
        self.onFinish = onFinish
    }

    var body: some View {
        KikiProPaywallSheet(
            manager: accessManager,
            context: context.kikiContext,
            copy: paywallCopy,
            footerLinks: paywallLinks,
            tint: CatKeyboardLockSettingsTint.brand,
            onFinish: finish
        )
    }

    private var paywallCopy: KikiProPaywallCopy {
        KikiProPaywallCopy(
            title: "Choose your plan",
            proSubtitle: "All features are unlocked.",
            trialSubtitle: "Choose a plan or continue with your trial.",
            expiredSubtitle: "Your trial has ended. Upgrade to keep using Pro.",
            notStartedSubtitle: "Keep keyboard and click locking available when you need it.",
            features: config.features,
            purchaseActionTitle: "Unlock forever",
            trialActionTitle: "Start 2-day free trial"
        )
    }

    private var paywallLinks: [KikiProPaywallLink] {
        [
            link(id: "terms", title: "Terms", value: config.termsURL),
            link(id: "privacy", title: "Privacy", value: config.privacyURL),
            link(id: "support", title: "Support", value: config.supportURL)
        ]
        .compactMap { $0 }
    }

    private func link(id: String, title: String, value: String) -> KikiProPaywallLink? {
        guard let url = URL(string: value) else {
            return nil
        }
        return KikiProPaywallLink(id: id, title: title, url: url)
    }

    private func finish() {
        onFinish?()
    }
}
