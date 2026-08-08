import XCTest
@testable import CatKeyboardLock

@MainActor
final class CatKeyboardLockAppArchitectureTests: XCTestCase {
    func testOnboardingUsesTheGuidedFreeSetupFlow() {
        let composition = CatKeyboardLockAppComposition(
            defaults: UserDefaults(suiteName: "CatKeyboardLockArchitecture.\(UUID().uuidString)")!,
            permissionClient: .testDenied
        )

        XCTAssertEqual(composition.onboardingCoordinator.configuration.steps.count, 1)
        XCTAssertTrue(composition.onboardingCoordinator.canSkip)
    }

    func testCompositionCanLockWithoutCommerceDependency() {
        let composition = CatKeyboardLockAppComposition(
            permissionClient: .testAllowed,
            eventTapFactory: { _, _ in TestEventTap() }
        )

        composition.router.requestLockAction()
        XCTAssertTrue(composition.inputLockController.state.isLocked)
    }
}

private final class TestEventTap: InputLockEventTapping {
    var isStarted = false
    func start() -> Bool { isStarted = true; return true }
    func stop() { }
}

private extension InputLockPermissionClient {
    static let testAllowed = InputLockPermissionClient(
        isAccessibilityTrusted: { _ in true }
    )

    static let testDenied = InputLockPermissionClient(
        isAccessibilityTrusted: { _ in false }
    )
}
