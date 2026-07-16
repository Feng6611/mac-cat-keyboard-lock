# Software Architecture

`cat keyboard lock` is a small macOS menu bar app built from the
`Kiki_menubar_starter` structure. AppKit owns the menu bar shell and platform
event tap. SwiftUI owns settings, onboarding, and paywall UI. Kiki packages own
reusable window, settings, menu, overlay, and trigger-corner infrastructure.

## Current Review

The current split is intentionally app-target based, not package-first:

- `App/` owns product definition, dependency composition, routing, and lifecycle
  coordination as four separate responsibilities.
- `Features/` owns user-facing surfaces.
- `Core/` exists only for pure product rules that now have a second consumer:
  the CLI test harness.
- `Platform/InputLock/` owns direct macOS input interception.
- `Shared/` owns app-local constants and copy.

This is enough separation for the current risk level. The four App types are a
repeatable app shell, not a generic framework layer. Do not add another
domain/service/use-case layer unless a rule needs another consumer or tests need
a cleaner seam.

The main redundancy risk is `Core/`: it is justified today because menu routing
rules are command-line testable, but it should not absorb SwiftUI view state,
RevenueCat state, defaults, Kiki adapters, or platform permissions.

## Boundaries

### App

`App/` owns the application shell:

- SwiftUI `App` entry point.
- `CatKeyboardLockAppDefinition` is immutable product configuration: app copy,
  access configuration, provider configuration, launch options, and stable
  autosave names.
- `CatKeyboardLockAppComposition` constructs and exposes the one long-lived
  instance of each service/coordinator. It contains construction, not behavior.
- `CatKeyboardLockAppRouter` is the only place that turns Core actions into
  input-lock, permission, Settings, paywall, onboarding, and quit actions.
- `CatKeyboardLockLifecycleCoordinator` owns menu bar/overlay/trigger-corner
  runtime objects, subscriptions, startup sequencing, and teardown.
- `NSApplicationDelegate` only forwards launch and termination to lifecycle.
- One `KikiAccessManager` is the paid-access source of truth, app-owned
  onboarding migration/presentation policy, and wiring between access state,
  lock state, and product actions.
- One `KikiSettingsCoordinator` owns Settings tab selection, exact native-window
  registration, and accessory-safe opening. A small app route model owns only
  the paywall sheet flag. `openPaywall()` selects About, opens Settings, and
  presents the app-owned sheet.
- One `KikiOnboardingCoordinator` owns the first-run window, page navigation,
  close disposition, and completion-store writes. Cat supplies permission and
  paywall step content plus legacy migration and automatic-presentation policy.
- Automatic onboarding waits for `KikiAccessManager.readiness == .ready`.
  A degraded/offline refresh may preserve cached active access but never treats
  missing entitlement data as proof that the user is unpaid. Explicit UI-smoke
  scenes remain deterministic and are presented once without waiting for the
  network.

### Features

`Features/` owns app-facing presentation:

- Menu item declaration in `CatKeyboardLockMenuModel`.
- Settings `Lock`, `System`, and `About` panes rendered through
  `KikiSettingsCoordinatorView`; About uses `KikiStandardAboutPane`.
- Product-specific onboarding steps and the thin Cat paywall copy/tint/link
  adapter. KikiOnboarding owns navigation/window mechanics;
  KikiCommercePresentation owns offering/action orchestration and renders the
  app-owned paywall; Cat owns where the sheet appears, CustomerInfo helpers,
  and what successful completion means.
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
  event tap installation/removal. Its onboarding practice entry point uses a
  keyboard-only policy and a fixed 60-second timeout.
- `InputLockEventTap` wraps Core Graphics event tap creation and teardown.
- `LockSettings` stores user preferences and derives the Core Graphics event
  mask used while locked.

This layer may import AppKit, ApplicationServices, CoreGraphics, and focused
Kiki platform modules for shared value types. It must not record input content
or upload data.

Trigger corner detection is delegated to `KikiTriggerCorner`:

- `LockSettings` persists the selected `KikiTriggerCorner` and enabled flag.
- `CatKeyboardLockLifecycleCoordinator` owns access gating and starts/stops
  `KikiTriggerCornerMonitor` only while an active trial/Pro entitlement exists
  or input is already locked.
- The trigger callback calls the existing lock/unlock flow and does not bypass
  `InputLockController`.
- Onboarding temporarily disables the persistent trigger monitor while its own
  monitor teaches the selected/default corner. It restores the prior setting on
  skip and enables the corner after a completed lock-and-unlock practice.
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
- `KikiSettings`: exact Settings-window registration, coordinator, standard
  About pane, shell, and reusable rows.
- `KikiPaywall`: commerce-free atoms plus `KikiCompactPaywall` and
  `KikiOnboardingPaywall` display presets.
- `KikiOnboarding`: completion stores, explicit close policy, and reusable
  flow/window coordination.
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

Kiki_mackit stays commerce-free and never calls RevenueCat or decides
entitlement state. The app supplies product IDs, RevenueCat configuration,
trial policy, copy, onboarding migration, and feature-gating decisions.

## Commerce Boundary

`KikiCommerceKit` keeps three one-way layers:

- `KikiCommerceCore` owns provider-neutral access/trial state and the single
  `KikiAccessManager`.
- `KikiRevenueCat` owns SDK configuration, offering/purchase/restore transport,
  snapshot mapping, and verified `AppTransaction` grandfathering.
- `KikiCommercePresentation` owns reusable app-controlled paywall transaction
  orchestration and maps manager state into Kiki paywall display models.

Cat does not mirror manager state in another observable manager. App-local
types are limited to product plan metadata, pure entitlement snapshots used by
lock/menu rules, configuration, onboarding migration, and copy. Existing
`KikiPro*` names are migration aliases only; Cat source uses `KikiAccess*`.

During coordinated development, Cat resolves Kiki and Commerce from adjacent
local checkouts, and Commerce resolves that same local Kiki checkout. Release
branches must switch all three repositories back to compatible exact tagged
HTTPS versions so SwiftPM resolves one identity for each shared package.

Cat also declares the same exact `purchases-ios-spm` version selected by
KikiCommerceKit and links only the `RevenueCat` product for typed CustomerInfo
access. SwiftPM must resolve exactly one package identity. `KikiAccessManager`
remains the only mutable access source; direct CustomerInfo reads are snapshots
for app-owned logic and must not become a second entitlement store.

RevenueCatUI, RevenueCat Paywall, and Customer Center are outside this
integration. All visible purchase and account surfaces remain owned by Cat and
Kiki components.

## Testing-First Shape

The architecture exposes three test surfaces:

1. Core CLI: deterministic product rules without launching the app.
2. Xcode tests: app integration, onboarding migration/policy, model behavior,
   purchase-state adapters, trigger-corner logic, and safe platform wrappers.
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
- Click suppression can interfere with menu bar interaction; the selected
  timeout is always available, and an enabled trigger corner can still respond
  to pointer movement.
- Permission failures are surfaced as state, not hidden behind a lock-looking UI.

## Release Readiness

The project generates its Info.plist from Xcode build settings. Before shipping,
configure signing, notarization, app icon, privacy/support URLs, and any final
entitlements required by the chosen distribution route.

Before release, use `Docs/Testing.md` as the checklist. Real Accessibility
grant, real lock, unlock, timeout, purchase, and restore remain manual smoke
tests because automating them can make the local Mac hard to recover or depend
on external App Store state.
