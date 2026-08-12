import CoreGraphics
import KikiMenuBar
import XCTest
@testable import CatKeyboardLock

@MainActor
final class CatKeyboardLockTests: XCTestCase {
    func testFreeAccessAlwaysAllowsLockFlow() {
        let evaluation = CatKeyboardLockCore.evaluate(
            CatKeyboardLockCoreInput(
                accessibilityTrusted: true
            )
        )

        XCTAssertEqual(evaluation.lockRequestAction, .lock)
        XCTAssertEqual(evaluation.menuLockTitle, "Lock Keyboard")
        XCTAssertTrue(evaluation.warnings.isEmpty)
    }

    func testFreeAccessWithMissingAccessibilityRequestsPermission() {
        let evaluation = CatKeyboardLockCore.evaluate(
            CatKeyboardLockCoreInput(
                accessibilityTrusted: false
            )
        )

        XCTAssertEqual(evaluation.lockRequestAction, .openPermission)
        XCTAssertEqual(evaluation.statusText, "Needs Accessibility")
    }

    private func menuTitles() -> [String] {
        CatKeyboardLockMenuModel.items(
            config: .default,
            lockState: .unlocked,
            lockSettings: LockSettings(defaults: isolatedDefaults()),
            accessibilityTrusted: true,
            actions: CatKeyboardLockMenuActions(
                requestLock: {},
                openSettings: {},
                quit: {}
            )
        )
        .compactMap(\.title)
    }

    func testMenuContainsNoPurchaseOrPaywallEntry() {
        let titles = menuTitles()

        XCTAssertTrue(titles.contains("Lock Keyboard"))
        XCTAssertFalse(titles.contains { $0.localizedCaseInsensitiveContains("upgrade") })
        XCTAssertFalse(titles.contains { $0.localizedCaseInsensitiveContains("trial") })
        XCTAssertFalse(titles.contains { $0.localizedCaseInsensitiveContains("purchase") })
    }

    func testDefaultPolicyOnlyLocksKeyboardEvents() {
        XCTAssertEqual(
            InputLockPolicy().suppressedEventTypes,
            [.keyDown, .keyUp, .flagsChanged]
        )
    }

    func testOnboardingCompletesAfterPracticeWithoutPaywall() {
        let defaults = isolatedDefaults()
        let settings = LockSettings(defaults: defaults)
        let controller = InputLockController(
            settings: settings,
            permissionClient: .testAllowed,
            eventTapFactory: { _, _ in CallbackInputLockEventTap() }
        )
        var didFinish = false
        let session = CatKeyboardLockOnboardingSession(
            lockSettings: settings,
            inputLockController: controller,
            onFinish: { didFinish = true }
        )

        session.start()
        session.advance()
        session.advance()
        session.handleCornerTrigger()
        session.handleCornerTrigger()
        XCTAssertEqual(session.phase, CatKeyboardLockOnboardingPhase.unlockSuccess)

        session.advance()
        XCTAssertTrue(didFinish)
        XCTAssertTrue(settings.triggerCornerEnabled)
    }
}

private func isolatedDefaults() -> UserDefaults {
    let suite = "CatKeyboardLockTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

private extension InputLockPermissionClient {
    static let testAllowed = InputLockPermissionClient(
        isAccessibilityTrusted: { _ in true }
    )
}

private final class CallbackInputLockEventTap: InputLockEventTapping {
    var isStarted = false
    func start() -> Bool { isStarted = true; return true }
    func stop() { isStarted = false }
}
