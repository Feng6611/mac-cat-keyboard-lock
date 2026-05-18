# Architecture

`cat keyboard lock` is a small macOS menu bar app built from the
`Kiki_menubar_starter` structure. AppKit owns the menu bar shell and platform
event tap. SwiftUI owns settings, onboarding, and paywall UI. Kiki packages own
reusable window, settings, menu, paywall, overlay, and trigger-corner
infrastructure.

## Boundaries

### App

`App/` owns the application shell:

- SwiftUI `App` entry point.
- `NSApplicationDelegate` and `.accessory` activation policy.
- Long-lived menu bar, settings, paywall, and input-lock controllers.
- App-owned Pro status, local trial persistence, onboarding presentation, and
  wiring between user actions, access state, lock state, and feature views.

### Features

`Features/` owns app-facing presentation:

- Menu item declaration in `CatKeyboardLockMenuModel`.
- Settings `Lock`, `System`, and `About` panes.
- Lightweight onboarding and RevenueCat-backed paywall presentation.

Feature code may import SwiftUI and Kiki. It should not own `CGEventTap`
lifecycle or other direct system interception behavior.

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
- `KikiPaywall`: reusable paywall display primitives.
- `KikiWindow`: standalone window presentation.
- `KikiDesign`: shared visual primitives.
- `KikiOverlay`: non-interactive screen-edge overlay and Kiki material toast
  presentation.
- `KikiTriggerCorner`: trigger-corner geometry, dwell/cooldown state, and
  AppKit monitor for host-owned actions.

Do not move cat keyboard lock input policy, unlock reasons, event tap behavior,
or Pro gating into Kiki.

Commerce and trial policy also stay in this app. `Kiki_mackit` provides reusable
app shell, presentation, and lightweight platform primitives; product IDs,
RevenueCat configuration, local trial state, restore behavior, and gating
decisions remain app-owned.

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
- Pointer blocking is opt-in and can interfere with menu bar interaction; the
  fallback combo and 10-minute timeout are always available.
- Permission failures are surfaced as state, not hidden behind a lock-looking UI.

## Release Readiness

The project generates its Info.plist from Xcode build settings. Before shipping,
configure signing, notarization, app icon, privacy/support URLs, and any final
entitlements required by the chosen distribution route.
