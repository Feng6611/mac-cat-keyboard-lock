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
| F-003 | Accessibility gate | User is guided before input locking needs permission and sees refreshed state after returning from System Settings | Menu / Settings / onboarding | Allowed / denied / changed while inactive | Core + Platform/UI | J-002 |
| F-004 | Keyboard/click policy | User chooses which input types are blocked | Settings Lock | Keyboard / clicks on/off | Core + Platform | J-002, J-004 |
| F-005 | Recovery unlock and timeout | User can regain input safely | Menu / trigger corner / timeout | Active / recovered | Platform/Manual | J-003 |
| F-006 | Trigger corner | User can lock from a configured corner, including after turning the setting off and on again | Settings System / screen corner | Enabled / disabled / re-enabled / dwell | Platform/Kiki | J-004 |
| F-007 | Onboarding | New user can skip setup or practice trigger-corner lock and unlock with a 60-second safety release | Onboarding | First run / permission / waiting for corner / locked / timeout / unlocked / completed | UI/App | J-001 |
| F-008 | Paywall and RevenueCat SDK | User can buy or restore either Apple lifetime unlock from the app-owned paywall | About status / onboarding sheet / paywall smoke | Loading / trial / paid / restore / cancel / error | UI/App/commerce | J-005 |
| F-009 | About and account status | User sees identity, entitlement status, support, and debug state clearly | Settings About | Release / debug / lifetime | UI | J-005 |

## Agent-Friendly Journey Cases

| Case ID | Journey | Covers | Boundary | Preconditions | Steps | Expected evidence | Cleanup |
| --- | --- | --- | --- | --- | --- | --- | --- |
| J-001 | First run and trial access | F-001, F-007 | UI/App/Core | Fresh, legacy-completed, already-Pro, offline/degraded, or reset onboarding state | Run lifecycle readiness and onboarding state tests, onboarding screenshot, and Core access cases | Setup can be deferred; the default corner advances lock/unlock without buttons; practice blocks only the keyboard; timeout restores input after 60 seconds; completed practice enables the corner | Unlock and reset onboarding/test state |
| J-002 | Lock selected input | F-002, F-003, F-004 | Core + Platform/Manual | Known access and permission states | Run Core matrix; change Accessibility in System Settings and return to the app; release smoke locks real input | JSON lock/openPermission action; permission status refreshes on app activation; real input is blocked only in manual smoke | Unlock and clear test override |
| J-003 | Unlock and recover safely | F-002, F-005 | Platform/Manual | App is locked in release smoke | Use menu, configured trigger corner, and timeout recovery | Input returns and menu title changes to lock | Ensure unlocked state |
| J-004 | Configure lock behavior | F-004, F-006 | UI + Platform | Debug build | Launch Settings smoke scenes, turn Trigger corner off and on, then dwell in the selected corner | Native Kiki Settings screenshots show controls; the re-enabled monitor triggers after dwell; tests pass | Quit app |
| J-005 | Review account, paywall, and support info | F-001, F-008, F-009 | UI/App/Manual | Trial/pro/error test states; Debug has a valid RevenueCat test key | Launch Settings About and the Kiki paywall through normal app actions; verify both non-consumable plan mappings and `$6.99`/`$10.99` fallback metadata; exercise CustomerInfo entitlement checks, purchase/restore callbacks, error/cancel handling; run sandbox purchase/restore manually | App-owned paywall exposes Lifetime and Support Developer Lifetime; either active product grants `cat keyboard lock Pro`; manager refresh follows CustomerInfo changes; failures remain visible | Reset test entitlement and sandbox purchases |

## Verification Matrix

| Feature / setting | Boundary | Core CLI | Xcode tests | UI smoke | Manual release smoke |
| --- | --- | --- | --- | --- | --- |
| Access state routing | Core | `script/catlock_core.sh matrix` | Pro status tests | About status and paywall sheet screenshots | Real purchase/restore |
| Lock / unlock menu action | Core + App | `evaluate` and `matrix` | Menu model and AppRouter action-matrix tests | No | Real lock/unlock |
| Accessibility required before lock | Core + Platform | `matrix` denied case | Permission adapter and activation-refresh tests | Permission copy screenshots | Real grant/deny and return-to-app refresh |
| Keyboard/click policy | Core + Platform | `matrix` policy cases | Event mask tests | Settings Lock screenshot | Real blocked input |
| Menu, trigger-corner, and timeout recovery | Platform | No | Controller timeout, trigger-corner, and event-tap disabled callback tests | No | Real recovery paths |
| Trigger corner | Platform/Kiki | No | Geometry/monitor and off-on lifecycle tests | Settings System screenshot | Real pointer dwell after off-on |
| Onboarding | UI/App | No | Trigger-corner practice, 60-second timeout, preference restoration, legacy migration, Pro skip, and trial tests | Onboarding screenshot; final step presents paywall sheet | Skip, corner lock/unlock, timeout, and active-trial path |
| Paywall | UI/App/commerce | Access rules only | Product mapping, CustomerInfo entitlement checks, purchase/restore refresh, and error/cancel adapter tests | About-triggered Kiki paywall screenshot | Real sandbox purchase/restore |
| About and account status | UI | No | App config tests | Settings About screenshot | Debug key and entitlement sanity check |

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
