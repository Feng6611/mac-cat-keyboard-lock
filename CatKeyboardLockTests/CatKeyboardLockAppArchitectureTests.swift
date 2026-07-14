import KikiCommerceCore
import XCTest
@testable import CatKeyboardLock

@MainActor
final class CatKeyboardLockAppArchitectureTests: XCTestCase {
    func testOnboardingWindowUsesCompactKikiGeometry() {
        XCTAssertEqual(CatKeyboardLockOnboardingFlow.windowSize.width, 560)
        XCTAssertEqual(CatKeyboardLockOnboardingFlow.windowSize.height, 520)
    }

    func testOnboardingUsesOneStatefulGuidedFlowBeforePaywallSheet() {
        let composition = makeComposition()

        XCTAssertEqual(
            CatKeyboardLockOnboardingPhase.allCases,
            [
                .welcome,
                .permission,
                .permissionSuccess,
                .lockWithCorner,
                .lockSuccess,
                .unlockWithCorner,
                .unlockSuccess
            ]
        )
        XCTAssertEqual(composition.onboardingCoordinator.configuration.steps.count, 1)
        XCTAssertFalse(composition.onboardingCoordinator.canSkip)
    }

    func testOnboardingRequiresPermissionThenUsesCornerToLockAndUnlock() {
        let composition = makeComposition(permissionClient: .architectureAllowed)
        var didFinish = false
        let session = CatKeyboardLockOnboardingSession(
            lockSettings: composition.lockSettings,
            inputLockController: composition.inputLockController,
            onFinish: { didFinish = true }
        )

        session.start()
        session.advance()
        XCTAssertEqual(session.phase, .permissionSuccess)

        session.advance()
        XCTAssertEqual(session.phase, .lockWithCorner)

        session.handleCornerTrigger()
        XCTAssertEqual(session.phase, .lockSuccess)
        XCTAssertTrue(composition.inputLockController.state.isLocked)

        session.advance()
        XCTAssertEqual(session.phase, .unlockWithCorner)

        session.handleCornerTrigger()
        XCTAssertEqual(session.phase, .unlockSuccess)
        XCTAssertEqual(composition.inputLockController.lastUnlockReason, .triggerCorner)

        session.advance()
        XCTAssertTrue(session.isPaywallPresented)

        session.complete()
        XCTAssertTrue(didFinish)
        XCTAssertTrue(composition.lockSettings.triggerCornerEnabled)
    }

    func testOnboardingDoesNotReachCornerTutorialWithoutPermission() {
        let composition = makeComposition(permissionClient: .architectureDenied)
        let session = CatKeyboardLockOnboardingSession(
            lockSettings: composition.lockSettings,
            inputLockController: composition.inputLockController,
            onFinish: {}
        )

        session.start()
        session.advance()
        session.requestAccessibility()

        XCTAssertEqual(session.phase, .permission)
        XCTAssertFalse(composition.inputLockController.state.isLocked)
    }

    func testCompositionCanUseInjectedCommerceAndPlatformClients() async {
        let defaults = isolatedDefaults()
        let commerceClient = ArchitectureCommerceClient()
        let eventTap = CallbackInputLockEventTap()
        let composition = makeComposition(
            defaults: defaults,
            commerceClient: commerceClient,
            permissionClient: .architectureAllowed,
            eventTap: eventTap
        )

        await composition.accessManager.refresh()
        composition.router.requestLockAction()

        XCTAssertTrue(composition.inputLockController.state.isLocked)
        XCTAssertTrue(eventTap.didStart)
        XCTAssertEqual(commerceClient.configureCallCount, 1)
    }

    func testRouterDrivesPermissionBranchFromActualPermissionState() {
        var didPresentPermissionHelp = false
        let composition = makeComposition(
            permissionClient: .architectureDenied,
            presentPermissionHelp: { didPresentPermissionHelp = true }
        )
        composition.router.requestLockAction()

        XCTAssertTrue(didPresentPermissionHelp)
        XCTAssertEqual(
            composition.inputLockController.state,
            .permissionRequired(reason: "Cat Keyboard Lock needs Accessibility to block input.")
        )
    }

    func testRouterDrivesInputSelectionAndPaywallBranches() {
        let composition = makeComposition(permissionClient: .architectureAllowed)
        composition.settingsCoordinator.select(.system)
        composition.lockSettings.lockKeyboard = false
        composition.lockSettings.lockMouseClicks = false

        composition.router.requestLockAction()

        XCTAssertEqual(composition.router.lastPerformedLockAction, .chooseInput)

        let inactiveDefaults = isolatedDefaults()
        inactiveDefaults.set(
            Date(timeIntervalSince1970: 0),
            forKey: CatKeyboardLockProDefaults.Keys.trialStartedAt
        )
        let inactiveComposition = makeComposition(
            defaults: inactiveDefaults,
            permissionClient: .architectureAllowed
        )
        inactiveComposition.router.requestLockAction()

        XCTAssertEqual(inactiveComposition.router.lastPerformedLockAction, .openPaywall)
        XCTAssertTrue(inactiveComposition.settingsRoute.isPaywallSheetPresented)
    }

    func testFallbackCallbackAlwaysTearsDownActiveLock() async {
        let eventTap = CallbackInputLockEventTap()
        let composition = makeComposition(
            permissionClient: .architectureAllowed,
            eventTap: eventTap
        )
        composition.router.requestLockAction()
        XCTAssertTrue(composition.inputLockController.state.isLocked)

        eventTap.simulateFallbackUnlock()
        await Task.yield()

        XCTAssertEqual(composition.inputLockController.state, .unlocked)
        XCTAssertEqual(composition.inputLockController.lastUnlockReason, .fallbackShortcut)
        XCTAssertTrue(eventTap.didStop)
    }

    func testTapDisabledCallbackTearsDownAndReportsFailure() async {
        let eventTap = CallbackInputLockEventTap()
        let composition = makeComposition(
            permissionClient: .architectureAllowed,
            eventTap: eventTap
        )
        composition.router.requestLockAction()

        eventTap.simulateDisabled(reason: "macOS disabled the event tap.")
        await Task.yield()

        XCTAssertEqual(
            composition.inputLockController.state,
            .failed(reason: "macOS disabled the event tap.")
        )
        XCTAssertEqual(composition.inputLockController.lastUnlockReason, .tapDisabled)
        XCTAssertTrue(eventTap.didStop)
    }

#if DEBUG
    func testAccessExpirationCannotBlockRecoveryForActiveLock() async {
        let composition = makeComposition(permissionClient: .architectureAllowed)
        composition.router.requestLockAction()
        XCTAssertTrue(composition.inputLockController.state.isLocked)

        composition.accessManager.setDebugProAccessOverride(.notPro)
        composition.router.requestLockAction()

        XCTAssertEqual(composition.router.lastPerformedLockAction, .unlock)
        XCTAssertEqual(composition.inputLockController.state, .unlocked)
    }
#endif

    func testDegradedReadinessDoesNotAutomaticallyPresentOnboarding() async {
        let client = ArchitectureCommerceClient()
        client.refreshError = .network
        let composition = makeComposition(commerceClient: client)

        await composition.accessManager.refresh()
        composition.router.showAutomaticOnboardingIfAllowed()

        guard case .degraded = composition.accessManager.readiness else {
            XCTFail("Expected degraded readiness.")
            return
        }
        XCTAssertFalse(composition.onboardingCoordinator.isVisible)
    }

    private func makeComposition(
        defaults: UserDefaults? = nil,
        commerceClient: ArchitectureCommerceClient? = nil,
        permissionClient: InputLockPermissionClient = .architectureDenied,
        presentPermissionHelp: (@MainActor () -> Void)? = nil,
        eventTap: CallbackInputLockEventTap? = nil
    ) -> CatKeyboardLockAppComposition {
        let commerceClient = commerceClient ?? ArchitectureCommerceClient()
        let eventTap = eventTap ?? CallbackInputLockEventTap()
        return CatKeyboardLockAppComposition(
            definition: .live(arguments: ["CatKeyboardLockTests"]),
            defaults: defaults ?? isolatedDefaults(),
            commerceClient: commerceClient,
            permissionClient: permissionClient,
            presentPermissionHelp: presentPermissionHelp,
            eventTapFactory: { _, onFallbackUnlock, onTapDisabled in
                eventTap.onFallbackUnlock = onFallbackUnlock
                eventTap.onTapDisabled = onTapDisabled
                return eventTap
            }
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "dev.kkuk.catkeyboardlock.architecture-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private extension InputLockPermissionClient {
    static let architectureAllowed = InputLockPermissionClient(
        isAccessibilityTrusted: { _ in true }
    )

    static let architectureDenied = InputLockPermissionClient(
        isAccessibilityTrusted: { _ in false }
    )
}

private final class CallbackInputLockEventTap: InputLockEventTapping {
    var onFallbackUnlock: (() -> Void)?
    var onTapDisabled: ((String) -> Void)?
    var didStart = false
    var didStop = false
    var isStarted: Bool { didStart && !didStop }

    func start() -> Bool {
        didStart = true
        return true
    }

    func stop() {
        didStop = true
    }

    func simulateFallbackUnlock() {
        onFallbackUnlock?()
    }

    func simulateDisabled(reason: String) {
        onTapDisabled?(reason)
    }
}

@MainActor
private final class ArchitectureCommerceClient: CommerceClient {
    var cachedEntitlement: CommerceEntitlement?
    var entitlementDidChange: ((CommerceEntitlement?) -> Void)?
    var refreshError: CommercePurchaseError?
    var configureCallCount = 0

    func configureIfNeeded() {
        configureCallCount += 1
    }

    func refreshEntitlement() async throws -> CommerceEntitlement? {
        if let refreshError { throw refreshError }
        return cachedEntitlement
    }

    func loadOffering() async throws -> CommerceOffering? { nil }
    func purchase(_ plan: CommercePlan) async throws -> CommerceEntitlement? { nil }
    func restorePurchases() async throws -> CommerceEntitlement? { nil }
}
