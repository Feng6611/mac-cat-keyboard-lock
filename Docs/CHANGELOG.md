# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Initialized `cat keyboard lock` from `Kiki_menubar_starter`.
- Documented the keyboard-lock MVP, safety model, and platform boundary.
- Planned manual menu bar lock/unlock, fallback long-press unlock, and
  selectable lock duration.
- Added `CGEventTap`-based input locking, Settings controls, menu state, tests,
  and a local build/run script.
- Added a global edge highlight for lock/unlock visual feedback.
- Added a five-level lock feedback setting.
- Added an optional trigger corner component that toggles the normal lock/unlock
  flow after the pointer dwells in a selected screen corner.
- Added a lightweight first-launch onboarding window with an explicit
  `Start 2-Day Pro Trial` action.
- Added app-owned Pro status, local one-time trial persistence, and
  RevenueCatCommerceKit-backed purchase and restore handling.
- Added two one-time Pro plan surfaces: Lifetime at `$5.99` and recommended
  Supporter Lifetime at `$10.99`.
- Added an app-owned paywall sheet opened from Settings About status and
  onboarding.
- Added a Debug-only test entry for forcing paid or unpaid Pro access while
  testing local builds.
- Set the trigger corner hot zone to 40pt for more reliable edge activation.

### Changed
- Bumped Kiki dependency to 0.6.0.
- Migrated overlay presentations to `KikiOverlayTone.success` for the
  lock-ended toast; preview tint/companion-tint are now inlined as
  app-owned colors since `KikiScreenEdgeOverlayPalette` is deprecated.
- Dropped the ignored `windowTitle:` argument from the
  `KikiSettingsWindowController` initializer.
- Reframed the starter paywall/mock entitlement flow during MVP development
  before replacing it with real Trial/Pro gating.
- Kept fallback unlock keyboard events in the event tap even when keyboard
  suppression is disabled.
- Staged local runs through `dist/CatKeyboardLock.app` so macOS privacy
  permissions bind to one stable app path instead of multiple DerivedData copies.
- Removed Input Monitoring from the permission model; Accessibility is the only
  requested privacy permission.
- Moved lock feedback onto the reusable `KikiOverlay` screen-edge overlay API,
  with stronger lock/unlock entry bursts, softer orange breathing, and 5-second
  Kiki material transition toasts.
- Strengthened overlay breathing so it animates edge opacity, glow expansion,
  and border width, and lengthened Settings previews enough to show the cycle.
- Moved breathing rhythm out of Settings and into KikiOverlay design defaults,
  using a continuous time-based curve so the locked state has a subtle visible
  pulse.
- Kept the menu bar symbol stable as `keyboard` and mapped lock/unlock to the
  status item active state plus a locked-state orange tint.
- Removed the Account tab and aligned form controls with
  `mac-command-reopen`'s native KikiSettingsPane pattern.
- Simplified input settings to Keyboard and Clicks, removing movement/drag/scroll
  suppression from the product surface and event filter.
- Renamed the shortcut setting to `Lock / unlock shortcut` and showed the same
  shortcut on both lock and unlock menu states.
- Split Settings into `Lock`, `System`, and `About` tabs. Settings now opens on
  `Lock`, with lock feedback grouped under `Shortcut & Safety`.
- Replaced the standalone orange Upgrade page and Settings Pro tab with a
  Command Reopen-style app-local paywall sheet.
- Updated onboarding's final step to present the same paywall sheet instead of
  embedding a separate card or hardcoded trial CTA.
- Replaced the duration stepper with fixed Lock duration choices: 5, 10, 30,
  and 60 minutes.
- Replaced the starter mock entitlement store with real Trial/Pro gating.
- New lock attempts now require an active trial or Pro purchase; unlock and
  timeout recovery remain available for already-active locks.
- Moved reusable trigger-corner geometry, dwell/cooldown timing, and pointer
  polling into `KikiTriggerCorner`; the app now owns only settings persistence,
  access gating, and lock/unlock callback wiring.
- Kept Settings opening in accessory mode through `KikiSettingsOpener` so opening
  Settings does not create a temporary Dock icon.
