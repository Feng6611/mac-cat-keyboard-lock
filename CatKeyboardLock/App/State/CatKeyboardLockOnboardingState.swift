import Foundation
import KikiOnboarding

@MainActor
final class CatKeyboardLockOnboardingState {
    static let completionKey = "CatKeyboardLock.Onboarding.v1"
    static let legacyCompletionKey = "CatKeyboardLock.Pro.hasCompletedOnboarding"

    let store: KikiOnboardingCompletionStore
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.store = KikiOnboardingUserDefaultsCompletionStore(defaults: defaults)
        migrateLegacyCompletionIfNeeded()
    }

    var hasCompleted: Bool { store.isCompleted(forKey: Self.completionKey) }

    func shouldShow(isPro: Bool, hasAccessOverride: Bool = false) -> Bool {
        !hasCompleted && !isPro && !hasAccessOverride
    }

    func markCompleted() { store.markCompleted(forKey: Self.completionKey) }

    func reset() {
        store.reset(forKey: Self.completionKey)
        defaults.removeObject(forKey: Self.legacyCompletionKey)
    }

    private func migrateLegacyCompletionIfNeeded() {
        guard defaults.object(forKey: Self.legacyCompletionKey) != nil else {
            return
        }

        if defaults.bool(forKey: Self.legacyCompletionKey), !hasCompleted {
            markCompleted()
        }
        defaults.removeObject(forKey: Self.legacyCompletionKey)
    }
}
