import Foundation
import KikiSettings
import SwiftUI

/// Cat Lock is free, so the tip jar is the only place it ever asks for money.
/// The ask stays out of the way until the app has actually earned it: the menu
/// bar entry only appears after repeated real use, and any of the entry points
/// can be dismissed for good.
@MainActor
final class CatKeyboardLockSupportState: ObservableObject {
    /// Number of completed locks before the menu bar shows the tip entry.
    static let menuEntryLockThreshold = 10

    private enum Keys {
        static let lockCount = "CatKeyboardLock.Support.lockCount"
        static let didSupport = "CatKeyboardLock.Support.didSupport"
    }

    @Published private(set) var lockCount: Int
    @Published private(set) var didSupport: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lockCount = defaults.integer(forKey: Keys.lockCount)
        self.didSupport = defaults.bool(forKey: Keys.didSupport)
    }

    var showsAboutCard: Bool { !didSupport }

    var showsMenuEntry: Bool { !didSupport && lockCount >= Self.menuEntryLockThreshold }

    func recordLock() {
        guard lockCount < Self.menuEntryLockThreshold else { return }
        lockCount += 1
        defaults.set(lockCount, forKey: Keys.lockCount)
    }

    /// Payment happens on an external site, so this is the user's own word for it.
    func markSupported() {
        guard !didSupport else { return }
        didSupport = true
        defaults.set(true, forKey: Keys.didSupport)
    }

#if DEBUG
    /// Developer-only switch for previewing both sides of the optional support UI.
    func toggleSupportedForDebug() {
        didSupport.toggle()
        defaults.set(didSupport, forKey: Keys.didSupport)
    }
#endif
}

enum CatKeyboardLockSupportLinks {
    static func openTipPage(_ config: CatKeyboardLockAppConfig) {
        KikiSettingsActions.openURL(config.tipURL)
    }

    static func openRepository(_ config: CatKeyboardLockAppConfig) {
        KikiSettingsActions.openURL(config.repositoryURL)
    }

    static func openCommandReopen(_ config: CatKeyboardLockAppConfig) {
        KikiSettingsActions.openURL(config.commandReopenURL)
    }

    static func openXProfile(_ config: CatKeyboardLockAppConfig) {
        KikiSettingsActions.openURL(config.xURL)
    }
}

/// The one ask Cat Lock makes, once, in About.
///
/// The primary action is the developer's other app, not the tip jar: for a
/// free app, "try the app I actually sell" costs the user nothing and is
/// worth far more than a can — it opens a funnel that can end in a purchase
/// and an App Store review, where a tip is a one-off. The can survives as a
/// quiet link because it is the only money path Cat Lock itself has, and
/// because the phrase is too much a part of this app to delete.
struct CatKeyboardLockSupportCard: View {
    let tint: Color
    let onTryCommandReopen: () -> Void
    let onStar: () -> Void
    let onFollowX: () -> Void
    let onTip: () -> Void
    let onAlreadySupported: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )

                Text("Like Cat Lock?")
                    .font(.headline)

                Spacer(minLength: 0)
            }

            Text("It's free and complete, built by one person on weekends — and the best support costs nothing: try Command Reopen, my other app. It brings minimized windows back when you Cmd+Tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Try Command Reopen", action: onTryCommandReopen)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)

                Button("Star on GitHub", action: onStar)
                    .buttonStyle(.link)

                Button("Follow on X", action: onFollowX)
                    .buttonStyle(.link)

                Button("Buy the cat a can…", action: onTip)
                    .buttonStyle(.link)

                Spacer(minLength: 0)

                Button("I already did", action: onAlreadySupported)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }
}
