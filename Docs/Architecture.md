# Software Architecture

Cat Keyboard Lock is a macOS menu bar utility. The app owns product behavior;
Kiki_mackit supplies reusable settings, onboarding, menu, overlay, and trigger
corner infrastructure.

## Boundaries

- `App/` composes the app, routes actions, and owns lifecycle startup/teardown.
- `Features/` contains menu bar, Settings, and onboarding presentation.
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
corner, onboarding completes directly. Settings About shows Free, Made by, and
one optional Support action: Star on GitHub.

## About links

The app uses Kiki's About pane for its standard identity and link presentation.
Author identity and URLs remain app-owned configuration. The only Support
action is Star on GitHub; the README contains the optional Buy Me a Coffee link.

## Safety model

The event tap is installed only while locked and is removed on unlock, timeout,
app termination, object deinitialization, or tap failure. It blocks keyboard
events only; pointer controls remain available for trigger-corner recovery.

## Testing shape

Core CLI proves deterministic menu titles and actions. Xcode tests prove
composition, onboarding, settings routing, and platform wrappers. UI smoke
launches only the same onboarding/settings scenes available to real users.
