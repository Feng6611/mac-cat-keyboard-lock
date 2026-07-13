# Cat Keyboard Lock Testing

Cat Keyboard Lock uses boundary-based testing. Core CLI proves deterministic
product rules, Xcode tests prove app integration and safe platform wrappers, UI
smoke proves user-visible windows, and manual smoke covers real macOS behavior
that should not be automated on a developer machine.

## Feature Inventory

| ID | Feature / setting | User goal | Entry point | States | Boundary | Tests |
| --- | --- | --- | --- | --- | --- | --- |
| F-001 | Access state routing | User knows whether locking is available or requires upgrade | Menu / paywall / About | Trial / pro / expired / not started | Core + commerce | J-001, J-005 |
| F-002 | Lock / unlock action | User can lock and unlock input from the menu bar | Menu extra | Locked / unlocked | Core + App + Manual | J-002, J-003 |
| F-003 | Accessibility gate | User is guided before input locking needs permission | Menu / Settings / onboarding | Allowed / denied | Core + Platform/UI | J-002 |
| F-004 | Keyboard/click policy | User chooses which input types are blocked | Settings Lock | Keyboard / clicks on/off | Core + Platform | J-002, J-004 |
| F-005 | Recovery unlock and timeout | User can regain input safely | Global shortcut / timeout | Active / recovered | Platform/Manual | J-003 |
| F-006 | Trigger corner | User can lock from a configured corner | Settings System / screen corner | Enabled / disabled / dwell | Platform/Kiki | J-004 |
| F-007 | Onboarding | New user reaches a useful first state without repeating onboarding after an upgrade | Onboarding | First run / completed / legacy completion / already Pro | UI/App | J-001 |
| F-008 | Paywall | User can upgrade or restore paid access with localized offerings and visible transaction feedback | About status / onboarding sheet / paywall smoke | Loading / trial / paid / restore / error | UI/App/commerce | J-005 |
| F-009 | About and debug status | User sees identity, support, and debug status clearly | Settings About | Release / debug | UI | J-005 |

## Agent-Friendly Journey Cases

| Case ID | Journey | Covers | Boundary | Preconditions | Steps | Expected evidence | Cleanup |
| --- | --- | --- | --- | --- | --- | --- | --- |
| J-001 | First run and trial access | F-001, F-007 | UI/App/Core | Fresh, legacy-completed, already-Pro, offline/degraded, or reset onboarding state | Run lifecycle readiness and onboarding state tests, onboarding screenshot, and Core access cases | Automatic onboarding waits for ready access; degraded state does not auto-present; explicit smoke scene presents once; legacy completion migrates; Pro users skip | Reset onboarding/test state |
| J-002 | Lock selected input | F-002, F-003, F-004 | Core + Platform/Manual | Known access and permission states | Run Core matrix; release smoke locks real input | JSON lock/openPermission action; real input is blocked only in manual smoke | Unlock and clear test override |
| J-003 | Unlock and recover safely | F-002, F-005 | Platform/Manual | App is locked in release smoke | Use shortcut/menu/timeout recovery | Input returns and menu title changes to lock | Ensure unlocked state |
| J-004 | Configure lock behavior | F-004, F-006 | UI + Platform | Debug build | Launch Settings smoke scenes, then let the app call `openSettings()` | Native Kiki Settings screenshots show controls; tests pass | Quit app |
| J-005 | Review account, paywall, and support info | F-001, F-008, F-009 | UI/App/Manual | Trial/pro/error test states | Load offerings; launch Settings About and paywall smoke scenes through normal app actions; exercise trial/purchase/restore adapters; release purchase/restore smoke | Localized offering metadata is presented; failures remain visible; successful trial/purchase/restore completes the host flow; entitled CTA dismisses instead of purchasing again | Reset test entitlement |

## Verification Matrix

| Feature / setting | Boundary | Core CLI | Xcode tests | UI smoke | Manual release smoke |
| --- | --- | --- | --- | --- | --- |
| Access state routing | Core | `script/catlock_core.sh matrix` | Pro status tests | About status and paywall sheet screenshots | Real purchase/restore |
| Lock / unlock menu action | Core + App | `evaluate` and `matrix` | Menu model and AppRouter action-matrix tests | No | Real lock/unlock |
| Accessibility required before lock | Core + Platform | `matrix` denied case | Permission adapter tests | Permission copy screenshots | Real grant/deny |
| Keyboard/click policy | Core + Platform | `matrix` policy cases | Event mask tests | Settings Lock screenshot | Real blocked input |
| Fallback unlock combo and timeout | Platform | No | Timing/controller tests including event-tap fallback and disabled callbacks | No | Real recovery path |
| Trigger corner | Platform/Kiki | No | Geometry/monitor tests | Settings System screenshot | Real pointer dwell |
| Onboarding | UI/App | No | Legacy completion migration, Pro skip, and trial/onboarding state tests | Onboarding screenshot; trial step presents paywall sheet | Close/skip/start-trial path |
| Paywall | UI/App/commerce | Access rules only | Offering load, purchase/restore completion, error feedback, and entitled CTA adapter tests | About-triggered paywall sheet screenshot | Real purchase/restore |
| About and debug status | UI | No | App config tests | Settings About screenshot | Debug build sanity check |

## Core CLI

Core tests cover product rules without launching the Mac app. Use this for
access state, permission state, menu action naming, warnings, and lock request
routing.

```bash
script/catlock_core.sh evaluate --access trial --accessibility denied --keyboard on
script/catlock_core.sh matrix
```

Expected output is JSON. The important fields are:

- `menuLockTitle`: the user-facing menu command.
- `lockRequestAction`: the next product action, such as `lock`, `openPermission`, or `openPaywall`.
- `warnings`: rule-level problems that should be visible in UI or logs.

Use this layer while building a feature and before changing UI.

## App Integration

App integration is still Xcode-native. It proves the app target builds,
dependencies resolve, and the SwiftUI/AppKit wiring compiles with tests.

```bash
xcodebuild test -project CatKeyboardLock.xcodeproj -scheme CatKeyboardLock -destination 'platform=macOS,arch=arm64'
xcodebuild build -project CatKeyboardLock.xcodeproj -scheme CatKeyboardLock -configuration Debug -destination 'platform=macOS,arch=arm64'
```

Use this layer before every commit.

## UI CLI

UI smoke tests launch fixed scenes and capture screenshots for review. The
launch arguments only choose the startup scene; the app must still call the same
entry points a real user action would call, such as `openSettings()`,
`openPaywall()`, or onboarding coordinator `start()`.

The capture script prefers the expected window title. When macOS redacts window
titles because the invoking terminal lacks Screen Recording metadata access, it
falls back to the frontmost normal window owned by the app; each scene is
launched in a fresh process so that fallback stays deterministic.

Do not add test-only Settings windows, duplicate Kiki panes, or alternate
paywall/onboarding surfaces for screenshots. UI smoke does not grant system
permissions, make purchases, or lock real input.

```bash
script/catlock_ui.sh onboarding
script/catlock_ui.sh settings-lock
script/catlock_ui.sh settings-system
script/catlock_ui.sh settings-about
script/catlock_ui.sh paywall
script/catlock_ui.sh smoke
```

Screenshots are written to `build/ui-smoke/`. Use this layer before release or
after changing onboarding, settings, paywall, menu entry points, or Kiki
component integration. `paywall` opens the same app-owned path used by menu and
access gating: Settings opens on About and presents the paywall sheet. There is
no Settings Pro tab and no standalone Upgrade window in the default flow.
`onboarding` starts at the first page; navigating to the trial step presents the
same paywall sheet.

## Release Smoke

Before release, run:

1. Confirm Feature Inventory and journey cases match the shipped behavior.
2. `script/catlock_core.sh matrix`.
3. Full Xcode test.
4. Debug build.
5. UI CLI smoke screenshots.
6. Confirm `CatKeyboardLockRevenueCatAPIKey` is non-empty in the signed Release
   app and the published privacy/support links resolve.
7. Manual check only for dangerous paths: real Accessibility grant, real lock,
   unlock, timeout, purchase, and restore.
