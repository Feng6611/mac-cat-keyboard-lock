import AppKit
import KikiCommerce
import SwiftUI

private enum CatKeyboardLockPaywallColors {
    static let brandAccent = Color(red: 0.58, green: 0.20, blue: 0.62)
}

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
    @ObservedObject var proStatusManager: CatKeyboardLockProStatusManager
    let context: CatKeyboardLockPaywallContext
    let onFinish: (() -> Void)?

    init(
        config: CatKeyboardLockAppConfig,
        proStatusManager: CatKeyboardLockProStatusManager,
        context: CatKeyboardLockPaywallContext,
        onFinish: (() -> Void)? = nil
    ) {
        self.config = config
        self.proStatusManager = proStatusManager
        self.context = context
        self.onFinish = onFinish
    }

    var body: some View {
        KikiProPaywallSheet(
            manager: proStatusManager.kikiProAccessManager,
            context: context.kikiContext,
            copy: paywallCopy,
            links: externalLinks,
            tint: CatKeyboardLockPaywallColors.brandAccent,
            icon: NSApplication.shared.applicationIconImage,
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
            proCardTitle: "Pro",
            proCardSubtitle: "All Cat Keyboard Lock Pro features are unlocked. Thank you for your support.",
            features: config.features
        )
    }

    private var externalLinks: KikiProExternalLinks {
        KikiProExternalLinks(
            termsURL: config.termsURL,
            privacyURL: config.privacyURL,
            supportURL: config.supportURL
        )
    }

    private func finish() {
        onFinish?()
    }
}
