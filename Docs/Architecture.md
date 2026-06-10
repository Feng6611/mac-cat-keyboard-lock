# Software Architecture

`cat keyboard lock` is a small macOS menu bar app built from the
`Kiki_menubar_starter` structure. AppKit owns the menu bar shell and platform
event tap. SwiftUI owns settings, onboarding, and paywall UI. Kiki packages own
reusable window, settings, menu, overlay, and trigger-corner infrastructure.

## Current Review

The current split is intentionally app-target based, not package-first:

- `App/` owns lifecycle and cross-feature wiring.
- `Features/` owns user-facing surfaces.
- `Core/` exists only for pure product rules that now have a second consumer:
  the CLI test harness.
- `Platform/InputLock/` owns direct macOS input interception.
- `Shared/` owns app-local constants and copy.

This is enough separation for the current risk level. Do not add another
domain/service/use-case layer unless a file becomes hard to understand, a rule
needs another consumer, or tests need a cleaner seam. The goal is stable
behavior and readable ownership, not more folders.

The main redundancy risk is `Core/`: it is justified today because menu routing
rules are command-line testable, but it should not absorb SwiftUI view state,
RevenueCat state, defaults, Kiki adapters, or platform permissions.

## Boundaries

### App

`App/` owns the application shell:

- SwiftUI `App` entry point.
- `NSApplicationDelegate` and `.accessory` activation policy.
- Long-lived menu bar, settings, onboarding, and input-lock controllers.
- App-owned Pro status, local trial persistence, onboarding presentation, and
  wiring between user actions, access state, lock state, and feature views.
- Settings scene presentation from an accessory app. Opening Settings uses
  `KikiSettingsOpener.openForMenuBarApp()` and must keep accessory mode so it
  does not create a temporary Dock icon.
- App-local settings navigation owns the selected tab and paywall sheet flag.
  `openPaywall()` always opens Settings, selects About, and presents the
  app-owned paywall sheet.

### Features

`Features/` owns app-facing presentation:

- Menu item declaration in `CatKeyboardLockMenuModel`.
- Settings `Lock`, `System`, and `About` panes.
- Lightweight onboarding and RevenueCat-backed paywall presentation. The Pro
  paywall is app-local business UI presented as a sheet from About status and
  from the onboarding trial step.
- Accessibility setup copy and routing into the app's permission request flow.

Feature code may import SwiftUI and Kiki. It should not own `CGEventTap`
lifecycle or other direct system interception behavior.

### Core

`Core/` owns product rules that do not need AppKit or SwiftUI:

- access state interpretation for not started, trial, expired, and Pro users.
- lock request routing into lock, unlock, permission setup, paywall, or input
  selection.
- menu lock title decisions shared by the app and the CLI test harness.

Core must stay deterministic and command-line testable. It should not read
`UserDefaults`, open windows, call RevenueCat, inspect system permissions, or
install event taps.

### Platform

`Platform/InputLock/` owns direct macOS input interception:

- `InputLockController` coordinates permission checks, lock state, timeout, and
  event tap installation/removal.
- `InputLockEventTap` wraps Core Graphics event tap creation and teardown.
- `LockSettings` stores user preferences and derives the Core Graphics event
  mask used while locked.
- `UnlockGestureDetector` contains pure timing logic for the fallback long press.

This layer may import AppKit, ApplicationServices, CoreGraphics, and focused
Kiki platform modules for shared value types. It must not record input content
or upload data.

Trigger corner detection is delegated to `KikiTriggerCorner`:

- `LockSettings` persists the selected `KikiTriggerCorner` and enabled flag.
- `CatKeyboardLockAppDelegate` owns access gating and starts/stops
  `KikiTriggerCornerMonitor` only while an active trial/Pro entitlement exists
  or input is already locked.
- The trigger callback calls the existing lock/unlock flow and does not bypass
  `InputLockController`.
- The reusable package owns pointer polling, multi-display corner geometry,
  dwell/cooldown timing, and re-arm behavior.

### Shared

`Shared/` owns app-local constants and product copy:

- App name, bundle ID, support/privacy/repository links.
- Menu bar title and paywall plan copy.
- Overlay presentation copy, settings preview copy, and unlock-reason mapping.
- Overlay style mapping from the user-facing maximum intensity preference.

## Kiki Boundary

Kiki remains reusable infrastructure:

- `KikiMenuBar`: `NSStatusItem` and native menu item mapping.
- `KikiSettings`: Settings window shell and reusable rows.
- `KikiPaywall`: reusable low-level paywall display primitives only.
- `KikiWindow`: standalone window presentation.
- `KikiDesign`: shared visual primitives.
- `KikiOverlay`: non-interactive screen-edge overlay and Kiki material toast
  presentation.
- `KikiTriggerCorner`: trigger-corner geometry, dwell/cooldown state, and
  AppKit monitor for host-owned actions.
- `KikiAuthorization`: Accessibility status, system prompt, and System Settings
  helper overlay.

Do not move cat keyboard lock input policy, unlock reasons, event tap behavior,
or Pro gating into Kiki.

Commerce, paywall presentation, and trial policy stay in this app.
`Kiki_mackit` provides reusable app shell, settings rows, presentation, and
lightweight platform primitives; product IDs, RevenueCat configuration, local
trial state, restore behavior, paywall layout, and gating decisions remain
app-owned. Kiki never calls RevenueCat or decides entitlement state.

## Testing-First Shape

The architecture exposes three test surfaces:

1. Core CLI: deterministic product rules without launching the app.
2. Xcode tests: app integration, model behavior, purchase-state adapters,
   trigger-corner logic, and platform wrappers that can be tested safely.
3. UI smoke CLI: fixed onboarding, settings, and paywall entry points that
   launch the built app and capture screenshots.

UI smoke launch arguments only choose the first scene. They must still wake the
same app-owned actions used by real menu items and buttons: `openSettings()`,
`openPaywall()` selecting About and presenting the sheet, onboarding `show()`,
and the normal lock/unlock controller methods. Do not add test-only Settings
windows, duplicate Kiki panes, standalone upgrade windows, or parallel
paywall/onboarding surfaces for screenshots.

This is why `Core/` is present. If a rule can be expressed as plain input to
plain output, it belongs there and should be reachable from `script/catlock_core.sh`.
`script/catlock_core.sh matrix` is the default quick proof for access,
permission, lock routing, menu title, and warning rules.
If a behavior depends on SwiftUI, AppKit windows, Kiki presentation, RevenueCat,
or permissions, keep it in `App/`, `Features/`, or `Platform/` and test it with
Xcode or UI smoke instead.

The UI smoke layer is not a replacement for manual safety checks. It proves
that key windows open and are visually reviewable. It does not grant
Accessibility, lock real input, make purchases, or restore purchases.

## Safety Model

- The event tap is installed only while locked and is removed on unlock,
  timeout, app termination, object deinit, or tap failure.
- The trigger corner monitor is active only while the setting is enabled and
  access is active trial/Pro or input is already locked. `KikiTriggerCorner`
  toggles through an app-owned callback into the normal lock/unlock flow instead
  of bypassing `InputLockController`, and lock state changes disarm the corner
  until the pointer exits.
- The default settings block only keyboard events, so menu bar `Unlock` remains
  usable.
- The menu bar item keeps one keyboard symbol and uses active state plus tint
  for locked/unlocked mode feedback.
- Pro gating blocks only new lock attempts. Existing locks keep their normal
  recovery paths even if a trial expires while locked.
- Click suppression can interfere with menu bar interaction; the fallback combo
  and selected timeout are always available.
- Permission failures are surfaced as state, not hidden behind a lock-looking UI.

## Release Readiness

The project generates its Info.plist from Xcode build settings. Before shipping,
configure signing, notarization, app icon, privacy/support URLs, and any final
entitlements required by the chosen distribution route.

Before release, use `Docs/Testing.md` as the checklist. Real Accessibility
grant, real lock, unlock, timeout, purchase, and restore remain manual smoke
tests because automating them can make the local Mac hard to recover or depend
on external App Store state.
