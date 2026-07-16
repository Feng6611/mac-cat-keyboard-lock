# Changelog

## 2026-07-15

- Removed the lock/unlock shortcut from the menu and input event filter.
- Onboarding now uses the default trigger corner to start and end a real
  keyboard-only practice without manual lock/unlock buttons. Input restores
  automatically after 60 seconds, and skipping preserves the prior setting.
- Clarified automatic 2-day trial terms, lifetime purchase actions, recovery
  guidance, menu punctuation, product naming, and lock feedback.
- Improved reusable plan-card labeling/selection accessibility and made
  purchase, restore, and trial failures operation-specific in the shared kits.
- Switched the coordinated development graph to adjacent Kiki and Commerce
  checkouts so Cat consumes these shared fixes before the release-tag sequence.

## 2026-07-14

- Added RevenueCat SDK support for two Apple lifetime products at `$6.99` and
  `$10.99`, automatic app-managed 2-day trial, CustomerInfo entitlement
  snapshots, and Debug/Release API-key build guards while retaining the
  app-owned Kiki purchase UI.
- Production builds now resolve `Kiki_mackit` from the public `0.8.1` tag and
  `KikiCommerceKit` from the public `0.1.1` tag; local sibling checkouts are
  no longer part of the app project graph.
- Transparent onboarding keeps its rounded parent window while the paywall
  sheet is presented.

## 2026-07-13

- Restored the onboarding welcome window to `560×520`; the guided flow now
  requires Accessibility first, celebrates authorization, teaches a real
  trigger-corner lock, celebrates, teaches trigger-corner recovery, celebrates
  again, and then presents a closeable `520×520` paywall sheet.
- Removed the onboarding-only 3-second lock API. Purchase success now gets a
  final celebration, and both paywall completion and dismissal hand off to the
  Lock tab in Settings.
- Reduced Developer Testing to two rows: paid-access state and compact
  Onboarding/Accessibility flow launchers.
- Kept standard step content near the top of the flexible body region so the
  hero and feature list do not drift into the middle of the window.
- Adopted Kiki's shared bundle-icon resolver for About and Onboarding instead
  of keeping an app-local `AppIcon.icns` lookup.

## 2026-07-10

- Split the application shell into AppDefinition, AppComposition, AppRouter,
  and LifecycleCoordinator; AppDelegate now only forwards lifecycle events.
- Routed all menu and trigger-corner lock requests through the Core action
  matrix using the real Accessibility state and selected input policy.
- Waited for authoritative Commerce readiness before automatic onboarding and
  prevented explicit UI-smoke scenes from being presented twice.
- Migrated app source to the product-neutral `KikiAccess*` API.
- Added injected composition, Core-to-production router, degraded-startup, event
  tap disabled, and fallback teardown regression tests.
- Added the privacy document referenced by Settings and paywall links.

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Changed
- Upgraded to Kiki_mackit 0.7.3 and aligned About, Paywall, Onboarding, and
  Debug surfaces with the `mac-command-reopen` design language.
  - About status now uses the canonical tone→icon→color mapping from
    `KikiAccessStatusTone`, with the brand tint threaded through the
    access-status row instead of a hardcoded purple.
  - Default About links are scoped to Website, Email, and GitHub only;
    Terms and Privacy continue to live in the paywall footer.
  - Paywall plan cards render vertically in an `HStack` inside a tinted
    `KikiPaywallStatsCard`; header title is 24pt bold and the message is
    plain text.
  - Onboarding window is 680×680 with no traffic lights, an 88×88 app-icon
    hero, 24pt bold title, and `KikiOnboardingProgressDots` above the
    action area.
- Replaced the boolean Pro debug override with `KikiProAccessDebugMode`
  (`live` / `notPro` / `trial` / `pro`). Settings exposes a
  `KikiSettingsDebugPreviewRow` segmented picker plus Trigger Onboarding
  and Clear Test Override actions; the menu bar toggle cycles between
  `.pro` and live.
- Centralized the app's brand color in `CatKeyboardLockSettingsTint.brand`
  so Settings, Paywall, and Onboarding share one tint source.

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
- Added a lightweight first-launch onboarding window with an automatic 2-day
  Pro trial.
- Added a single KikiCommerceKit access manager, local one-time trial policy,
  and RevenueCat-backed purchase and restore handling.
- Added two one-time Pro plan surfaces: Lifetime at `$6.99` and Support
  Developer Lifetime at `$10.99`.
- Added an app-owned paywall sheet opened from Settings About status and
  onboarding.
- Added a Debug-only test entry for forcing paid or unpaid Pro access while
  testing local builds.
- Set the trigger corner hot zone to 40pt for more reliable edge activation.

### Changed
- Replaced the app-local Pro status wrapper with direct
  `KikiProAccessManager` observation across App, Settings, Onboarding, Paywall,
  and Menu.
- Split provider-neutral Commerce configuration from RevenueCat configuration
  and migrated the app to the three KikiCommerceKit targets.
- Routed onboarding completion through `KikiOnboardingCompletionStore`, with a
  one-time migration from the legacy completion key and preserved Pro/debug
  skip behavior.
- Moved Paywall layout to Kiki presets while retaining CommercePresentation
  orchestration for offerings, serialized transactions, visible feedback, and
  successful host completion.
- Adopted `KikiSettingsCoordinatorView` and exact Settings-window registration;
  About now uses `KikiStandardAboutPane`.
- Replaced the app-local onboarding window and page state machine with
  `KikiOnboardingCoordinator`, while retaining Cat-owned permission and
  paywall content.
- Preserved distinct open plan identities for Lifetime and Supporter Lifetime
  from provider mapping through access status and presentation.
- Added Terms, Privacy, and Support links to the shared paywall presentation.
- Unified local Cat/Commerce integration on one Kiki_mackit package identity;
  release builds must switch to matching tagged HTTPS dependencies.
- Updated the app integration to the Kiki 0.7.0 API.
- Migrated overlay presentations to `KikiOverlayTone.success` for the
  lock-ended toast; preview tint/companion-tint are now inlined as
  app-owned colors since `KikiScreenEdgeOverlayPalette` is deprecated.
- Removed app-side Settings window lookup and navigation wrappers.
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
