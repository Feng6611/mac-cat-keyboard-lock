import CoreGraphics
import KikiCommerceCore
import KikiMenuBar
import KikiOverlay
import KikiTriggerCorner
import XCTest
@testable import CatKeyboardLock

@MainActor
final class CatKeyboardLockTests: XCTestCase {
    func testMenuModelForUnlockedState() {
        let items = CatKeyboardLockMenuModel.items(
            config: .default,
            lockState: .unlocked,
            lockSettings: LockSettings(defaults: isolatedDefaults()),
            entitlement: CatKeyboardLockEntitlementSnapshot(isPro: false, isTrialActive: true),
            accessibilityTrusted: true,
            actions: noOpActions
        )

        var expectedTitles = [
            "Ready to lock",
            "Lock Keyboard",
            "Settings...",
            "Upgrade to Pro...",
            "Quit Cat Keyboard Lock"
        ]
#if DEBUG
        expectedTitles.insert("Test Paid Access", at: expectedTitles.count - 1)
        expectedTitles.insert("Clear Test Override", at: expectedTitles.count - 1)
#endif

        XCTAssertEqual(items.compactMap(\.title), expectedTitles)
        XCTAssertEqual(menuItem(titled: "Ready to lock", in: items)?.isEnabled, false)
        XCTAssertEqual(menuItem(titled: "Lock Keyboard", in: items)?.isEnabled, true)
        XCTAssertEqual(
            actionShortcut(titled: "Lock Keyboard", in: items),
            KikiMenuShortcut(key: "l", modifiers: [.control, .option, .command])
        )
    }

    func testMenuModelForLockedState() {
        let items = CatKeyboardLockMenuModel.items(
            config: .default,
            lockState: .locked(startedAt: Date(timeIntervalSince1970: 0)),
            lockSettings: LockSettings(defaults: isolatedDefaults()),
            entitlement: CatKeyboardLockEntitlementSnapshot(isPro: true, isTrialActive: false),
            accessibilityTrusted: true,
            actions: noOpActions
        )

        XCTAssertNotNil(menuItem(titled: "Unlock", in: items))
        XCTAssertEqual(
            actionShortcut(titled: "Unlock", in: items),
            KikiMenuShortcut(key: "l", modifiers: [.control, .option, .command])
        )
        XCTAssertNil(menuItem(titled: "Upgrade to Pro...", in: items))
    }

    func testMenuModelRoutesNotStartedLockToPaywall() {
        var didRequestLock = false
        let items = CatKeyboardLockMenuModel.items(
            config: .default,
            lockState: .unlocked,
            lockSettings: LockSettings(defaults: isolatedDefaults()),
            entitlement: CatKeyboardLockEntitlementSnapshot(status: .notStarted),
            accessibilityTrusted: false,
            actions: CatKeyboardLockMenuActions(
                requestLock: { didRequestLock = true },
                openSettings: {},
                openPaywall: {},
                quit: {}
            )
        )

        guard case .action(_, _, _, let action) = menuItem(titled: "Start Trial / Upgrade...", in: items) else {
            XCTFail("Expected lock entry to route to paywall.")
            return
        }

        action()
        XCTAssertTrue(didRequestLock)
    }

    func testMenuModelRoutesExpiredLockToPaywallButKeepsUnlockAvailable() {
        var didRequestLock = false
        let unlockedItems = CatKeyboardLockMenuModel.items(
            config: .default,
            lockState: .unlocked,
            lockSettings: LockSettings(defaults: isolatedDefaults()),
            entitlement: CatKeyboardLockEntitlementSnapshot(status: .expired),
            accessibilityTrusted: true,
            actions: CatKeyboardLockMenuActions(
                requestLock: { didRequestLock = true },
                openSettings: {},
                openPaywall: {},
                quit: {}
            )
        )

        guard case .action(_, _, _, let action) = menuItem(titled: "Upgrade to Lock...", in: unlockedItems) else {
            XCTFail("Expected expired lock entry to route to paywall.")
            return
        }

        action()
        XCTAssertTrue(didRequestLock)

        let lockedItems = CatKeyboardLockMenuModel.items(
            config: .default,
            lockState: .locked(startedAt: Date(timeIntervalSince1970: 0)),
            lockSettings: LockSettings(defaults: isolatedDefaults()),
            entitlement: CatKeyboardLockEntitlementSnapshot(status: .expired),
            accessibilityTrusted: true,
            actions: noOpActions
        )

        XCTAssertNotNil(menuItem(titled: "Unlock", in: lockedItems))
        XCTAssertNil(menuItem(titled: "Upgrade to Lock...", in: lockedItems))
    }

    func testCoreEvaluationRoutesInactiveAccessToPaywall() {
        let evaluation = CatKeyboardLockCore.evaluate(
            CatKeyboardLockCoreInput(
                access: .notStarted,
                accessibilityTrusted: false,
                lockKeyboard: true,
                lockMouseClicks: false
            )
        )

        XCTAssertEqual(evaluation.menuLockTitle, "Start Trial / Upgrade...")
        XCTAssertEqual(evaluation.lockRequestAction, .openPaywall)
        XCTAssertEqual(evaluation.statusText, "Trial not started")
        XCTAssertEqual(evaluation.permissionText, "Needs permission")
    }

    func testCoreEvaluationRoutesActiveMissingPermissionToPermissionSetup() {
        let evaluation = CatKeyboardLockCore.evaluate(
            CatKeyboardLockCoreInput(
                access: .trial,
                accessibilityTrusted: false,
                lockKeyboard: true,
                lockMouseClicks: false
            )
        )

        XCTAssertEqual(evaluation.menuLockTitle, "Lock Keyboard")
        XCTAssertEqual(evaluation.lockRequestAction, .openPermission)
        XCTAssertEqual(evaluation.statusText, "Needs Accessibility")
        XCTAssertEqual(evaluation.warnings, ["Accessibility is required before input can be locked."])
    }

    func testCoreEvaluationNamesClickLockAndEmptyPolicy() {
        let clickEvaluation = CatKeyboardLockCore.evaluate(
            CatKeyboardLockCoreInput(
                access: .pro,
                accessibilityTrusted: true,
                lockKeyboard: true,
                lockMouseClicks: true
            )
        )

        XCTAssertEqual(clickEvaluation.menuLockTitle, "Lock Input")
        XCTAssertEqual(clickEvaluation.lockRequestAction, .lock)
        XCTAssertEqual(clickEvaluation.policySummary, ["keyboard", "clicks"])

        let emptyEvaluation = CatKeyboardLockCore.evaluate(
            CatKeyboardLockCoreInput(
                access: .pro,
                accessibilityTrusted: true,
                lockKeyboard: false,
                lockMouseClicks: false
            )
        )

        XCTAssertEqual(emptyEvaluation.lockRequestAction, .chooseInput)
        XCTAssertEqual(emptyEvaluation.statusText, "Choose input to lock")
    }

#if DEBUG
    func testDebugPaidAccessToggleAppearsInMenu() {
        var didToggle = false
        var didClear = false
        let items = CatKeyboardLockMenuModel.items(
            config: .default,
            lockState: .unlocked,
            lockSettings: LockSettings(defaults: isolatedDefaults()),
            entitlement: CatKeyboardLockEntitlementSnapshot(isPro: true, isTrialActive: false),
            accessibilityTrusted: true,
            actions: CatKeyboardLockMenuActions(
                requestLock: {},
                openSettings: {},
                openPaywall: {},
                toggleDebugProAccess: { didToggle = true },
                clearDebugProAccessOverride: { didClear = true },
                quit: {}
            )
        )

        guard case .toggle(_, true, true, let toggleAction) = menuItem(titled: "Test Paid Access", in: items) else {
            XCTFail("Expected a checked debug Pro toggle.")
            return
        }

        toggleAction()
        XCTAssertTrue(didToggle)

        guard case .action(_, _, true, let clearAction) = menuItem(titled: "Clear Test Override", in: items) else {
            XCTFail("Expected a clear override action.")
            return
        }

        clearAction()
        XCTAssertTrue(didClear)
    }
#endif

    func testDefaultPolicyOnlyLocksKeyboardEvents() {
        let policy = InputLockPolicy(
            lockKeyboard: true,
            lockMouseClicks: false
        )

        XCTAssertEqual(policy.suppressedEventTypes, [.keyDown, .keyUp, .flagsChanged])
    }

    func testClickOptionExtendsPolicyMask() {
        let policy = InputLockPolicy(
            lockKeyboard: true,
            lockMouseClicks: true
        )

        XCTAssertEqual(policy.suppressedEventTypes, [
            .keyDown,
            .keyUp,
            .flagsChanged,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp
        ])
    }

    func testVisualFeedbackSettingsPersistAndMapToOverlayStyle() {
        let defaults = isolatedDefaults()
        let settings = LockSettings(defaults: defaults)

        XCTAssertEqual(settings.overlayEffectLevel, LockSettings.defaultOverlayEffectLevel)

        settings.overlayEffectLevel = 1

        let reloaded = LockSettings(defaults: defaults)
        XCTAssertEqual(reloaded.overlayEffectLevel, 1)

        let style = CatKeyboardLockOverlayPresentations.style(for: reloaded)
        XCTAssertEqual(style.breathingDuration, KikiScreenEdgeOverlayStyle.defaultBreathingDuration)
        XCTAssertEqual(style.glowDepth, 17.6, accuracy: 0.0001)
        XCTAssertGreaterThan(style.edgeLineWidth, 0)
    }

    func testTriggerCornerSettingsPersist() {
        let defaults = isolatedDefaults()
        let settings = LockSettings(defaults: defaults)

        XCTAssertFalse(settings.triggerCornerEnabled)
        XCTAssertEqual(settings.triggerCorner, .topRight)

        settings.triggerCornerEnabled = true
        settings.triggerCorner = .bottomLeft

        let reloaded = LockSettings(defaults: defaults)
        XCTAssertTrue(reloaded.triggerCornerEnabled)
        XCTAssertEqual(reloaded.triggerCorner, .bottomLeft)
        XCTAssertEqual(reloaded.triggerCornerConfiguration.edgeSize, 40)
    }

    func testTriggerCornerGeometryHandlesMultipleScreens() {
        let frames = [
            CGRect(x: 0, y: 0, width: 100, height: 100),
            CGRect(x: 100, y: 0, width: 100, height: 100)
        ]

        XCTAssertTrue(
            KikiTriggerCornerGeometry.contains(
                point: CGPoint(x: 198, y: 98),
                screenFrames: frames,
                corner: .topRight,
                edgeSize: 12
            )
        )
        XCTAssertFalse(
            KikiTriggerCornerGeometry.contains(
                point: CGPoint(x: 150, y: 50),
                screenFrames: frames,
                corner: .topRight,
                edgeSize: 12
            )
        )
    }

    func testTriggerCornerActivationRequiresDwellAndExitToRearm() {
        var activation = KikiTriggerCornerActivationState()
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertFalse(
            activation.update(
                isInsideCorner: true,
                now: start,
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
        XCTAssertFalse(
            activation.update(
                isInsideCorner: true,
                now: start.addingTimeInterval(0.44),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
        XCTAssertTrue(
            activation.update(
                isInsideCorner: true,
                now: start.addingTimeInterval(0.46),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
        XCTAssertFalse(
            activation.update(
                isInsideCorner: true,
                now: start.addingTimeInterval(2.2),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )

        XCTAssertFalse(
            activation.update(
                isInsideCorner: false,
                now: start.addingTimeInterval(2.3),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
        XCTAssertFalse(
            activation.update(
                isInsideCorner: true,
                now: start.addingTimeInterval(2.4),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
        XCTAssertTrue(
            activation.update(
                isInsideCorner: true,
                now: start.addingTimeInterval(2.9),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
    }

    func testTriggerCornerActivationCanWaitForExitBeforeArming() {
        var activation = KikiTriggerCornerActivationState()
        let start = Date(timeIntervalSince1970: 0)

        activation.disarmUntilExit()

        XCTAssertFalse(
            activation.update(
                isInsideCorner: true,
                now: start.addingTimeInterval(1),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
        XCTAssertFalse(
            activation.update(
                isInsideCorner: false,
                now: start.addingTimeInterval(1.1),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
        XCTAssertFalse(
            activation.update(
                isInsideCorner: true,
                now: start.addingTimeInterval(1.2),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
        XCTAssertTrue(
            activation.update(
                isInsideCorner: true,
                now: start.addingTimeInterval(1.7),
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )
    }

    func testTriggerCornerMonitorCallsLockAfterDwell() {
        let settings = LockSettings(defaults: isolatedDefaults())
        settings.triggerCornerEnabled = true
        settings.triggerCorner = .topRight

        var pointer = CGPoint(x: 99, y: 99)
        var triggerCount = 0
        let monitor = KikiTriggerCornerMonitor(
            configurationProvider: {
                KikiTriggerCornerConfiguration(
                    isEnabled: settings.triggerCornerEnabled,
                    corner: settings.triggerCorner
                )
            },
            mouseLocationProvider: { pointer },
            screenFramesProvider: { [CGRect(x: 0, y: 0, width: 100, height: 100)] },
            onTrigger: {
                triggerCount += 1
            }
        )
        let start = Date(timeIntervalSince1970: 0)

        monitor.evaluate(now: start)
        monitor.evaluate(now: start.addingTimeInterval(0.44))
        XCTAssertEqual(triggerCount, 0)

        monitor.evaluate(now: start.addingTimeInterval(0.46))
        XCTAssertEqual(triggerCount, 1)

        monitor.evaluate(now: start.addingTimeInterval(2.2))
        XCTAssertEqual(triggerCount, 1)

        pointer = CGPoint(x: 50, y: 50)
        monitor.evaluate(now: start.addingTimeInterval(2.3))
        pointer = CGPoint(x: 99, y: 99)
        monitor.evaluate(now: start.addingTimeInterval(2.4))
        monitor.evaluate(now: start.addingTimeInterval(2.9))

        XCTAssertEqual(triggerCount, 2)
    }

    func testTriggerCornerMonitorCanBeDisarmedAfterStateChange() {
        let settings = LockSettings(defaults: isolatedDefaults())
        settings.triggerCornerEnabled = true
        settings.triggerCorner = .topRight

        var triggerCount = 0
        let monitor = KikiTriggerCornerMonitor(
            configurationProvider: {
                KikiTriggerCornerConfiguration(
                    isEnabled: settings.triggerCornerEnabled,
                    corner: settings.triggerCorner
                )
            },
            mouseLocationProvider: { CGPoint(x: 99, y: 99) },
            screenFramesProvider: { [CGRect(x: 0, y: 0, width: 100, height: 100)] },
            onTrigger: {
                triggerCount += 1
            }
        )
        let start = Date(timeIntervalSince1970: 0)

        monitor.evaluate(now: start)
        monitor.disarmUntilExit()
        monitor.evaluate(now: start.addingTimeInterval(1))

        XCTAssertEqual(triggerCount, 0)
    }

    func testTriggerCornerMonitorUsesForgivingCornerZone() {
        let settings = LockSettings(defaults: isolatedDefaults())
        settings.triggerCornerEnabled = true
        settings.triggerCorner = .bottomLeft

        var triggerCount = 0
        let monitor = KikiTriggerCornerMonitor(
            configurationProvider: {
                KikiTriggerCornerConfiguration(
                    isEnabled: settings.triggerCornerEnabled,
                    corner: settings.triggerCorner
                )
            },
            mouseLocationProvider: { CGPoint(x: 20, y: 20) },
            screenFramesProvider: { [CGRect(x: 0, y: 0, width: 100, height: 100)] },
            onTrigger: {
                triggerCount += 1
            }
        )
        var activation = KikiTriggerCornerActivationState()
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertTrue(
            KikiTriggerCornerGeometry.contains(
                point: CGPoint(x: 20, y: 20),
                screenFrames: [CGRect(x: 0, y: 0, width: 100, height: 100)],
                corner: .bottomLeft,
                edgeSize: 32
            )
        )
        XCTAssertFalse(
            activation.update(
                isInsideCorner: true,
                now: start,
                dwellDuration: 0.45,
                cooldownDuration: 1.5
            )
        )

        monitor.evaluate(now: start)
        monitor.evaluate(now: start.addingTimeInterval(0.46))

        XCTAssertEqual(triggerCount, 1)
    }

    func testFallbackUnlockEventsStayObservedForClickOnlyLock() {
        let policy = InputLockPolicy(
            lockKeyboard: false,
            lockMouseClicks: true
        )

        XCTAssertTrue(policy.includes(.keyDown))
        XCTAssertFalse(policy.shouldSuppress(.keyDown))
        XCTAssertTrue(policy.shouldSuppress(.leftMouseDown))
    }

    func testFallbackUnlockRequiresExactComboAndHold() {
        var detector = UnlockGestureDetector(requiredHoldDuration: 1)

        XCTAssertEqual(
            detector.observe(
                eventType: .keyDown,
                keyCode: UnlockGestureDetector.unlockKeyCode,
                flags: [.maskControl, .maskCommand],
                timestamp: 0
            ),
            .none
        )

        XCTAssertEqual(
            detector.observe(
                eventType: .keyDown,
                keyCode: UnlockGestureDetector.unlockKeyCode,
                flags: [.maskControl, .maskAlternate, .maskCommand],
                timestamp: 0
            ),
            .holding(token: 1, shouldScheduleTimer: true)
        )

        XCTAssertEqual(
            detector.observe(
                eventType: .keyDown,
                keyCode: UnlockGestureDetector.unlockKeyCode,
                flags: [.maskControl, .maskAlternate, .maskCommand],
                timestamp: 0.9
            ),
            .holding(token: 1, shouldScheduleTimer: false)
        )

        XCTAssertEqual(
            detector.observe(
                eventType: .keyDown,
                keyCode: UnlockGestureDetector.unlockKeyCode,
                flags: [.maskControl, .maskAlternate, .maskCommand],
                timestamp: 1.0
            ),
            .unlock
        )
    }

    func testTimeoutUnlockStopsEventTap() {
        let settings = LockSettings(defaults: isolatedDefaults())
        let fakeTap = FakeInputLockEventTap()
        let controller = InputLockController(
            settings: settings,
            permissionClient: .allowed,
            eventTapFactory: { _, _, _ in fakeTap }
        )

        controller.lock(now: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(controller.state.isLocked)
        XCTAssertTrue(fakeTap.didStart)

        controller.expireLockForTesting()

        XCTAssertFalse(controller.state.isLocked)
        XCTAssertEqual(controller.lastUnlockReason, .timeout)
        XCTAssertTrue(fakeTap.didStop)
    }

    func testRefreshPermissionsDoesNotForcePermissionRequiredAtLaunch() {
        let settings = LockSettings(defaults: isolatedDefaults())
        let controller = InputLockController(
            settings: settings,
            permissionClient: .denied,
            eventTapFactory: { _, _, _ in FakeInputLockEventTap() }
        )

        controller.refreshPermissions()

        XCTAssertEqual(controller.state, .unlocked)
        XCTAssertFalse(controller.permissionStatus.accessibilityTrusted)
    }

    func testLockFailureNamesMissingAccessibility() {
        let settings = LockSettings(defaults: isolatedDefaults())
        let fakeTap = FakeInputLockEventTap(shouldStart: false)
        let controller = InputLockController(
            settings: settings,
            permissionClient: .denied,
            eventTapFactory: { _, _, _ in fakeTap }
        )

        controller.lock(now: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(
            controller.state,
            .permissionRequired(reason: "Cat Keyboard Lock needs Accessibility to block input.")
        )
    }

    func testLockCanStartWhenAccessibilityIsEnabled() {
        let settings = LockSettings(defaults: isolatedDefaults())
        let fakeTap = FakeInputLockEventTap()
        let controller = InputLockController(
            settings: settings,
            permissionClient: .allowed,
            eventTapFactory: { _, _, _ in fakeTap }
        )

        controller.lock(now: Date(timeIntervalSince1970: 0))

        XCTAssertTrue(controller.state.isLocked)
        XCTAssertTrue(fakeTap.didStart)
        XCTAssertTrue(controller.permissionStatus.accessibilityTrusted)
    }

    func testTapFailureReportsGenericFailure() {
        let settings = LockSettings(defaults: isolatedDefaults())
        let fakeTap = FakeInputLockEventTap(shouldStart: false)
        let controller = InputLockController(
            settings: settings,
            permissionClient: .allowed,
            eventTapFactory: { _, _, _ in fakeTap }
        )

        controller.lock(now: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(
            controller.state,
            .failed(reason: "macOS refused the input filter. Try quitting and reopening the app.")
        )
    }

    func testRequestPermissionsOnlyRequestsAccessibility() {
        let settings = LockSettings(defaults: isolatedDefaults())
        let controller = InputLockController(
            settings: settings,
            permissionClient: .allowed,
            eventTapFactory: { _, _, _ in FakeInputLockEventTap() }
        )

        controller.requestPermissions()

        XCTAssertEqual(controller.state, .unlocked)
    }

    func testRequestPermissionsShowsAuthorizationHelpWhenDenied() {
        let settings = LockSettings(defaults: isolatedDefaults())
        var didPresentPermissionHelp = false
        let controller = InputLockController(
            settings: settings,
            permissionClient: .denied,
            presentPermissionHelp: {
                didPresentPermissionHelp = true
            },
            eventTapFactory: { _, _, _ in FakeInputLockEventTap() }
        )

        controller.requestPermissions()

        XCTAssertTrue(didPresentPermissionHelp)
        XCTAssertEqual(
            controller.state,
            .permissionRequired(reason: "Cat Keyboard Lock needs Accessibility to block input.")
        )
    }

    func testProStatusStartsTwoDayTrialOnInitialization() {
        let defaults = isolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let manager = KikiAccessManager(
            configuration: CatKeyboardLockRevenueCatConfiguration.accessConfiguration,
            defaults: defaults,
            commerceClient: MockCommerceClient(),
            now: { now }
        )

        let expectedExpiresAt = now.addingTimeInterval(CatKeyboardLockRevenueCatConfiguration.trialDuration)
        XCTAssertEqual(defaults.object(forKey: CatKeyboardLockProDefaults.Keys.trialStartedAt) as? Date, now)
        XCTAssertEqual(
            manager.status,
            .trial(.time(daysRemaining: 2, expiresAt: expectedExpiresAt))
        )
    }

    func testOnboardingStateMigratesLegacyCompletion() {
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: CatKeyboardLockOnboardingState.legacyCompletionKey)

        let state = CatKeyboardLockOnboardingState(defaults: defaults)

        XCTAssertTrue(state.hasCompleted)
        XCTAssertNil(defaults.object(forKey: CatKeyboardLockOnboardingState.legacyCompletionKey))
    }

    func testOnboardingStateSkipsAutomaticPresentationForProUsers() {
        let state = CatKeyboardLockOnboardingState(defaults: isolatedDefaults())

        XCTAssertTrue(state.shouldShow(isPro: false))
        XCTAssertFalse(state.shouldShow(isPro: true))
        XCTAssertFalse(state.shouldShow(isPro: false, hasAccessOverride: true))
    }

    func testAutomaticTrialKeepsStableStartDate() async {
        let defaults = isolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let manager = KikiAccessManager(
            configuration: CatKeyboardLockRevenueCatConfiguration.accessConfiguration,
            defaults: defaults,
            commerceClient: MockCommerceClient(),
            now: { now }
        )

        let originalStart = defaults.object(forKey: CatKeyboardLockProDefaults.Keys.trialStartedAt) as? Date
        await manager.startTrial()

        let expectedExpiresAt = now.addingTimeInterval(CatKeyboardLockRevenueCatConfiguration.trialDuration)
        XCTAssertEqual(originalStart, now)
        XCTAssertEqual(defaults.object(forKey: CatKeyboardLockProDefaults.Keys.trialStartedAt) as? Date, now)
        XCTAssertEqual(
            manager.status,
            .trial(.time(daysRemaining: 2, expiresAt: expectedExpiresAt))
        )
    }

    func testExpiredTrialCannotRestart() async {
        let defaults = isolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let originalStart = now.addingTimeInterval(-CatKeyboardLockRevenueCatConfiguration.trialDuration)
        defaults.set(originalStart, forKey: CatKeyboardLockProDefaults.Keys.trialStartedAt)
        let manager = KikiAccessManager(
            configuration: CatKeyboardLockRevenueCatConfiguration.accessConfiguration,
            defaults: defaults,
            commerceClient: MockCommerceClient(),
            now: { now }
        )

        await manager.startTrial()

        XCTAssertEqual(defaults.object(forKey: CatKeyboardLockProDefaults.Keys.trialStartedAt) as? Date, originalStart)
        XCTAssertEqual(manager.status, .expired)
    }

#if DEBUG
    func testDebugProAccessOverrideForcesPaidAndUnpaid() {
        let defaults = isolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(now, forKey: CatKeyboardLockProDefaults.Keys.trialStartedAt)
        let expectedTrial = KikiAccessState.trial(
            .time(
                daysRemaining: 2,
                expiresAt: now.addingTimeInterval(CatKeyboardLockRevenueCatConfiguration.trialDuration)
            )
        )
        let manager = KikiAccessManager(
            configuration: CatKeyboardLockRevenueCatConfiguration.accessConfiguration,
            defaults: defaults,
            commerceClient: MockCommerceClient(),
            now: { now }
        )

        XCTAssertNil(manager.debugProAccessOverride)
        XCTAssertEqual(manager.status, expectedTrial)

        manager.setDebugProAccessOverride(.pro)

        let debugEntitlement = CommerceEntitlement(
            plan: CatKeyboardLockPurchasePlan.lifetime.commercePlan,
            productIdentifier: "debug.\(CatKeyboardLockPurchasePlan.lifetime.id)",
            entitlementIdentifier: "debug.pro",
            expirationDate: nil,
            willRenew: false,
            originalPurchaseDate: nil
        )
        XCTAssertEqual(manager.debugProAccessOverride, .pro)
        XCTAssertEqual(
            manager.status,
            .pro(plan: CatKeyboardLockPurchasePlan.lifetime.kikiAccessPlan, entitlement: debugEntitlement)
        )

        manager.setDebugProAccessOverride(.notPro)

        XCTAssertEqual(manager.debugProAccessOverride, .notPro)
        XCTAssertEqual(manager.status, .notStarted)

        manager.clearDebugProAccessOverride()

        XCTAssertNil(manager.debugProAccessOverride)
        XCTAssertEqual(manager.status, expectedTrial)
        XCTAssertNil(defaults.object(forKey: CatKeyboardLockProDefaults.Keys.debugProAccessOverride))
    }
#endif

    func testPurchasePlansUnlockPro() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        for plan in CatKeyboardLockPurchasePlan.allCases {
            let client = MockCommerceClient()
            let entitlement = CommerceEntitlement(
                plan: plan.commercePlan,
                productIdentifier: productIdentifier(for: plan),
                entitlementIdentifier: CatKeyboardLockRevenueCatConfiguration.entitlementIdentifier,
                expirationDate: nil,
                originalPurchaseDate: now
            )
            client.purchaseEntitlement = entitlement
            let manager = KikiAccessManager(
                configuration: CatKeyboardLockRevenueCatConfiguration.accessConfiguration,
                defaults: isolatedDefaults(),
                commerceClient: client,
                now: { now }
            )

            try await manager.purchase(planID: plan.id)

            XCTAssertEqual(manager.status, .pro(plan: plan.kikiAccessPlan, entitlement: entitlement))
        }
    }

    func testRestoreSuccessAndNoPurchaseFeedback() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let restoreClient = MockCommerceClient()
        let restoreEntitlement = CommerceEntitlement(
            plan: CatKeyboardLockPurchasePlan.supporterLifetime.commercePlan,
            productIdentifier: CatKeyboardLockRevenueCatConfiguration.supporterProductIdentifier,
            entitlementIdentifier: CatKeyboardLockRevenueCatConfiguration.entitlementIdentifier,
            expirationDate: nil,
            originalPurchaseDate: now
        )
        restoreClient.restoreEntitlement = restoreEntitlement
        let restoreManager = KikiAccessManager(
            configuration: CatKeyboardLockRevenueCatConfiguration.accessConfiguration,
            defaults: isolatedDefaults(),
            commerceClient: restoreClient,
            now: { now }
        )

        try await restoreManager.restorePurchases()
        XCTAssertEqual(
            restoreManager.status,
            .pro(plan: CatKeyboardLockPurchasePlan.supporterLifetime.kikiAccessPlan, entitlement: restoreEntitlement)
        )
        XCTAssertEqual(restoreManager.commerceFeedback, .restoreSucceeded)

        let emptyClient = MockCommerceClient()
        let emptyManager = KikiAccessManager(
            configuration: CatKeyboardLockRevenueCatConfiguration.accessConfiguration,
            defaults: isolatedDefaults(),
            commerceClient: emptyClient,
            now: { now }
        )

        try await emptyManager.restorePurchases()
        XCTAssertEqual(
            emptyManager.status,
            .trial(
                .time(
                    daysRemaining: 2,
                    expiresAt: now.addingTimeInterval(CatKeyboardLockRevenueCatConfiguration.trialDuration)
                )
            )
        )
        XCTAssertEqual(emptyManager.commerceFeedback, .noActivePurchase)
    }

    func testPurchasePlanMapsToOpenCommerceAndKikiPlans() {
        XCTAssertEqual(CatKeyboardLockPurchasePlan.defaultSelection, .lifetime)
        XCTAssertEqual(CatKeyboardLockPurchasePlan.allCases.map(\.id), ["lifetime", "supporterLifetime"])

        for purchasePlan in CatKeyboardLockPurchasePlan.allCases {
            let plan = purchasePlan.kikiAccessPlan
            XCTAssertEqual(purchasePlan.commercePlan.rawValue, purchasePlan.id)
            XCTAssertEqual(CatKeyboardLockPurchasePlan(commercePlan: purchasePlan.commercePlan), purchasePlan)
            XCTAssertEqual(plan.id, purchasePlan.id)
        }

        XCTAssertEqual(CatKeyboardLockPurchasePlan.lifetime.kikiAccessPlan.fallbackDisplayPrice, "$6.99")
        XCTAssertEqual(CatKeyboardLockPurchasePlan.supporterLifetime.kikiAccessPlan.fallbackDisplayPrice, "$10.99")
        XCTAssertEqual(CatKeyboardLockPurchasePlan.lifetime.kikiAccessPlan.badge, "Default")
        XCTAssertEqual(CatKeyboardLockPurchasePlan.supporterLifetime.kikiAccessPlan.badge, "Support Developer")
    }

    func testRevenueCatConfigurationMapsAllProductIdentifiers() {
        let identifiers = CatKeyboardLockRevenueCatConfiguration.commerceConfiguration.productIdentifiers

        XCTAssertEqual(
            identifiers[CatKeyboardLockPurchasePlan.lifetime.commercePlan],
            "dev.kkuk.catkeyboardlock.pro.lifetime"
        )
        XCTAssertEqual(
            identifiers[CatKeyboardLockPurchasePlan.supporterLifetime.commercePlan],
            "dev.kkuk.catkeyboardlock.pro.supporter"
        )
        XCTAssertEqual(CatKeyboardLockRevenueCatConfiguration.entitlementIdentifier, "cat keyboard lock Pro")
    }

    func testCustomerInfoSnapshotCarriesAppOwnedEntitlementResult() {
        let managementURL = URL(string: "https://apps.apple.com/account/subscriptions")
        let snapshot = CatKeyboardLockCustomerInfoSnapshot(
            hasProAccess: true,
            managementURL: managementURL
        )

        XCTAssertTrue(snapshot.hasProAccess)
        XCTAssertEqual(snapshot.managementURL, managementURL)
    }

    func testAppConfigAboutLinks() {
        let config = CatKeyboardLockAppConfig.default

        XCTAssertEqual(config.bundleID, "dev.kkuk.catkeyboardlock")
        XCTAssertEqual(config.repositoryDisplayName, "Feng6611/mac-cat-keyboard-lock")
        XCTAssertEqual(config.contactEmailAddress, "fchen6611@gmail.com")
    }

    func testOverlayPresentationsMapLockLifecycle() {
        let locked = CatKeyboardLockOverlayPresentations.lockStarted()

        XCTAssertEqual(locked.title, "Keyboard locked")
        XCTAssertEqual(locked.subtitle, "Hold ⌃⌥⌘L to unlock")
        XCTAssertEqual(locked.systemImage, "lock.fill")
        XCTAssertEqual(locked.behavior, .persistent)
        XCTAssertEqual(locked.motion, .breathingWithEntryBurst)

        let unlocked = CatKeyboardLockOverlayPresentations.lockEnded(reason: .manual)

        XCTAssertEqual(unlocked.title, "Keyboard unlocked")
        XCTAssertEqual(unlocked.subtitle, "Your keyboard is active.")
        XCTAssertEqual(unlocked.systemImage, "checkmark")
        XCTAssertEqual(unlocked.behavior, .momentary(duration: 5.35))
        XCTAssertEqual(unlocked.motion, .breathingWithEntryBurst)
        XCTAssertEqual(unlocked.edgeDuration, 1.5)
    }

    func testOverlayPresentationsMapUnlockReasonsAndWarnings() {
        XCTAssertEqual(
            CatKeyboardLockOverlayPresentations.lockEnded(reason: .fallbackShortcut).title,
            "Unlocked with shortcut"
        )
        XCTAssertEqual(
            CatKeyboardLockOverlayPresentations.lockEnded(reason: .triggerCorner).title,
            "Unlocked from corner"
        )
        XCTAssertEqual(
            CatKeyboardLockOverlayPresentations.lockEnded(reason: .timeout).title,
            "Lock duration ended"
        )
        XCTAssertEqual(
            CatKeyboardLockOverlayPresentations.lockEnded(reason: .tapDisabled).title,
            "Keyboard restored"
        )

        let warning = CatKeyboardLockOverlayPresentations.warning(reason: "Enable Accessibility.")

        XCTAssertEqual(warning.title, "Lock stopped")
        XCTAssertEqual(warning.subtitle, "Enable Accessibility.")
        XCTAssertEqual(warning.motion, .blink)
        XCTAssertEqual(warning.edgeDuration, 1.8)

        let preview = CatKeyboardLockOverlayPresentations.settingsPreview()

        XCTAssertEqual(preview.title, "Visual feedback")
        XCTAssertEqual(preview.subtitle, "Preview")
        XCTAssertEqual(preview.motion, .breathingWithEntryBurst)
        XCTAssertEqual(preview.toastDuration, 1.4)
        XCTAssertEqual(preview.edgeDuration ?? 0, 4.4, accuracy: 0.0001)
        if case .momentary(let duration) = preview.behavior {
            XCTAssertEqual(duration, 4.85, accuracy: 0.0001)
        } else {
            XCTFail("Expected momentary preview behavior.")
        }
    }

    private var noOpActions: CatKeyboardLockMenuActions {
        CatKeyboardLockMenuActions(
            requestLock: {},
            openSettings: {},
            openPaywall: {},
            quit: {}
        )
    }

    private func menuItem(titled title: String, in items: [KikiMenuItem]) -> KikiMenuItem? {
        items.first { $0.title == title }
    }

    private func actionShortcut(titled title: String, in items: [KikiMenuItem]) -> KikiMenuShortcut? {
        guard let item = menuItem(titled: title, in: items),
              case .action(_, let shortcut, _, _) = item else {
            return nil
        }
        return shortcut
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "dev.kkuk.catkeyboardlock.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func productIdentifier(for plan: CatKeyboardLockPurchasePlan) -> String {
        switch plan {
        case .lifetime:
            return CatKeyboardLockRevenueCatConfiguration.lifetimeProductIdentifier
        case .supporterLifetime:
            return CatKeyboardLockRevenueCatConfiguration.supporterProductIdentifier
        }
    }
}

private extension InputLockPolicy {
    func includes(_ eventType: CGEventType) -> Bool {
        eventMask & Self.mask(for: eventType) != 0
    }
}

private extension InputLockPermissionClient {
    static let allowed = InputLockPermissionClient(
        isAccessibilityTrusted: { _ in true }
    )

    static let denied = InputLockPermissionClient(
        isAccessibilityTrusted: { _ in false }
    )
}

private final class FakeInputLockEventTap: InputLockEventTapping {
    let shouldStart: Bool
    var didStart = false
    var didStop = false
    var isStarted: Bool { didStart && !didStop }

    init(shouldStart: Bool = true) {
        self.shouldStart = shouldStart
    }

    func start() -> Bool {
        didStart = true
        return shouldStart
    }

    func stop() {
        didStop = true
    }
}

@MainActor
private final class MockCommerceClient: CommerceClient {
    var cachedEntitlement: CommerceEntitlement?
    var entitlementDidChange: ((CommerceEntitlement?) -> Void)?

    var currentOffering: CommerceOffering?
    var fetchedEntitlement: CommerceEntitlement?
    var purchaseEntitlement: CommerceEntitlement?
    var restoreEntitlement: CommerceEntitlement?
    var offeringsError: Error?
    var entitlementError: Error?
    var purchaseError: Error?
    var restoreError: Error?
    var configureCallCount = 0
    var loadOfferingCallCount = 0
    var refreshEntitlementCallCount = 0

    func configureIfNeeded() {
        configureCallCount += 1
    }

    func refreshEntitlement() async throws -> CommerceEntitlement? {
        refreshEntitlementCallCount += 1

        if let entitlementError {
            throw entitlementError
        }

        return fetchedEntitlement
    }

    func loadOffering() async throws -> CommerceOffering? {
        loadOfferingCallCount += 1

        if let offeringsError {
            throw offeringsError
        }

        return currentOffering
    }

    func purchase(_ plan: CommercePlan) async throws -> CommerceEntitlement? {
        if let purchaseError {
            throw purchaseError
        }

        return purchaseEntitlement
    }

    func restorePurchases() async throws -> CommerceEntitlement? {
        if let restoreError {
            throw restoreError
        }

        return restoreEntitlement
    }
}
