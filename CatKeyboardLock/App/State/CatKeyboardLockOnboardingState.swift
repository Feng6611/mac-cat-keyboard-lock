import Foundation
import KikiOnboarding

@MainActor
final class CatKeyboardLockOnboardingState {
    static let completionKey = "CatKeyboardLock.Onboarding.v1"

    let store: KikiOnboardingCompletionStore

    init(defaults: UserDefaults = .standard) {
        self.store = KikiOnboardingUserDefaultsCompletionStore(defaults: defaults)
    }

    var hasCompleted: Bool { store.isCompleted(forKey: Self.completionKey) }
    var shouldShow: Bool { !hasCompleted }

    func markCompleted() { store.markCompleted(forKey: Self.completionKey) }
    func reset() { store.reset(forKey: Self.completionKey) }
}
