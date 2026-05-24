# cat keyboard lock - Agent Notes

This app was initialized from `Kiki_menubar_starter` and keeps its docs-first
workflow.

## Workflow

1. Research platform behavior and existing Kiki/starter boundaries.
2. Update `Docs/` before changing product behavior.
3. Maintain the Feature Inventory and Agent-friendly journey cases in
   `Docs/Testing.md` before choosing Core CLI, Xcode, UI smoke, or manual smoke
   coverage.
4. Keep product-specific input locking inside this app, not `Kiki_mackit`.
5. Keep UI smoke launch arguments wired to the same app-owned actions used by
   real menu items and buttons. Do not add test-only Settings windows or
   duplicate Kiki panes for screenshots.
6. Verify with unit tests and the local run script.

## Boundaries

- Kiki provides menu bar, settings, paywall, window, and design infrastructure.
- `Platform/InputLock/` owns `CGEventTap`, permission checks, timeout, and
  fallback unlock detection.
- Trial, purchase, and entitlement policy is app-owned and may gate new lock
  attempts. It must not interrupt recovery for an already-active lock.
- Do not add root helpers, DriverKit, IOHID, or system extensions for this MVP.

## Verification

```sh
git diff --check
./script/catlock_core.sh evaluate --access trial --accessibility denied --keyboard on
./script/catlock_core.sh matrix
xcodebuild test -project CatKeyboardLock.xcodeproj \
  -scheme CatKeyboardLock \
  -destination 'platform=macOS,arch=arm64'
./script/catlock_ui.sh smoke
```

The UI smoke command verifies fixed windows and screenshots only. Real
Accessibility grant, real lock/unlock, timeout, purchase, and restore remain
manual release smoke checks.
