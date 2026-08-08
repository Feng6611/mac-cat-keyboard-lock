# Software Architecture

Cat Keyboard Lock is a macOS menu bar utility. The app owns product behavior;
Kiki_mackit supplies reusable settings, onboarding, menu, overlay, and trigger
corner infrastructure.

## Boundaries

- `App/` composes the app, routes actions, and owns lifecycle startup/teardown.
- `Features/` contains menu bar, Settings, onboarding, and developer-tip
  presentation.
- `Core/` contains pure lock-routing rules. It has no AppKit, persistence,
  network, commerce, or payment dependency.
- `Platform/InputLock/` owns Accessibility checks, `CGEventTap`, timeout, and
  failsafe unlock behavior.
- `Shared/` contains app copy, URLs, and overlay presentation values.

The app has no IAP, subscription, trial, RevenueCat, commerce manager, account,
or paid feature gate. `Core` no longer models access at all: new lock attempts
only branch on selected input policy and Accessibility.

## User flow

The menu bar routes Lock/Unlock and Settings. First launch presents a skippable
guided setup. After the user practices locking and unlocking from the trigger
corner, onboarding completes directly. Settings About explains that the app is
free forever and carries the tip jar.

## Developer tip jar

Cat Lock is distributed outside the Mac App Store, so the optional tip is an
external Buy Me a Coffee link (`config.tipURL`) rather than an in-app purchase.
A Mac App Store build would have to drop these entry points, because linking
out to a payment page conflicts with App Review guideline 3.1.1.

`CatKeyboardLockSupportState` decides when the ask is allowed to appear and
persists two keys in `UserDefaults`:

- the About pane shows a support card until the user says they already gave;
- the menu bar gains a single `Buy the Cat a Can…` item only after
  `menuEntryLockThreshold` completed locks;
- onboarding shows one low-key link on the final celebration step;
- `I already did` hides every ask permanently. Payment happens on an external
  site, so the user's word is the only signal the app can have.

Nothing is ever presented as a modal, a badge, or a repeated prompt.

## Safety model

The event tap is installed only while locked and is removed on unlock, timeout,
app termination, object deinitialization, or tap failure. The default policy
blocks only keyboard events. Clicks are opt-in, and pointer movement remains
available for trigger-corner recovery.

## Testing shape

Core CLI proves deterministic menu titles and actions. Xcode tests prove
composition, onboarding, settings routing, and platform wrappers. UI smoke
launches only the same onboarding/settings scenes available to real users.
