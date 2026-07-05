import AppKit
import KikiCommerceCore
import KikiCommercePresentation
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
            tint: CatKeyboardLockPaywallColors.brandAccent,
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
            features: config.features
        )
    }

    private func finish() {
        onFinish?()
    }
}
