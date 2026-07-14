import AppKit
import KikiCommerceCore
import KikiCommercePresentation
import SwiftUI

enum CatKeyboardLockPaywallContext {
    case settings
    case onboarding

    var kikiContext: KikiAccessPaywallContext {
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
    @ObservedObject var accessManager: KikiAccessManager
    let context: CatKeyboardLockPaywallContext
    let onFinish: (() -> Void)?

    @State private var isCelebratingPurchase = false
    @State private var didHandleFinish = false

    init(
        config: CatKeyboardLockAppConfig,
        accessManager: KikiAccessManager,
        context: CatKeyboardLockPaywallContext,
        onFinish: (() -> Void)? = nil
    ) {
        self.config = config
        self.accessManager = accessManager
        self.context = context
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            KikiAccessPaywallSheet(
                manager: accessManager,
                context: context.kikiContext,
                copy: paywallCopy,
                footerLinks: paywallLinks,
                tint: CatKeyboardLockSettingsTint.brand,
                onFinish: finish
            )

            if isCelebratingPurchase {
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea()

                CatKeyboardLockCelebrationMark(
                    tint: CatKeyboardLockSettingsTint.brand,
                    title: "Pro unlocked"
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isCelebratingPurchase)
    }

    private var paywallCopy: KikiAccessPaywallCopy {
        KikiAccessPaywallCopy(
            title: "Unlock Pro forever",
            proSubtitle: "All features are unlocked.",
            trialSubtitle: "Choose a plan or continue with your trial.",
            expiredSubtitle: "Your trial has ended. Upgrade to keep using Pro.",
            notStartedSubtitle: "Keep keyboard and click locking available when you need it.",
            features: config.features,
            purchaseActionTitle: "Unlock Pro",
            trialActionTitle: "Continue 2-day free trial"
        )
    }

    private var paywallLinks: [KikiAccessPaywallLink] {
        [
            link(id: "terms", title: "Terms", value: config.termsURL),
            link(id: "privacy", title: "Privacy", value: config.privacyURL),
            link(id: "support", title: "Support", value: config.supportURL)
        ]
        .compactMap { $0 }
    }

    private func link(id: String, title: String, value: String) -> KikiAccessPaywallLink? {
        guard let url = URL(string: value) else {
            return nil
        }
        return KikiAccessPaywallLink(id: id, title: title, url: url)
    }

    private func finish() {
        guard didHandleFinish == false else { return }
        didHandleFinish = true

        if accessManager.commerceFeedback == .purchaseSucceeded {
            isCelebratingPurchase = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                onFinish?()
            }
        } else {
            onFinish?()
        }
    }
}
