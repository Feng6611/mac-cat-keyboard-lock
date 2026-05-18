# cat keyboard lock - Agent Notes

This app was initialized from `Kiki_menubar_starter` and keeps its docs-first
workflow.

## Workflow

1. Research platform behavior and existing Kiki/starter boundaries.
2. Update `Docs/` before changing product behavior.
3. Keep product-specific input locking inside this app, not `Kiki_mackit`.
4. Verify with unit tests and the local run script.

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
xcodebuild test -project CatKeyboardLock.xcodeproj \
  -scheme CatKeyboardLock \
  -destination 'platform=macOS,arch=arm64'
./script/build_and_run.sh --verify
```
