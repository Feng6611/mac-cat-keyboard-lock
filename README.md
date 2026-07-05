# cat keyboard lock

A macOS menu bar utility that temporarily blocks keyboard input after the user
turns it on. The MVP is intentionally manual and recovery-first: default lock
mode blocks only keyboard events, while pointer blocking is opt-in from
Settings.

## Features

- Menu bar `Lock Keyboard` / `Unlock` flow.
- Default keyboard-only lock.
- Optional click blocking.
- Optional trigger corner for starting a lock from a selected screen corner.
- Fallback unlock: hold `Control + Option + Command + L` for 1 second.
- Selectable lock duration: 5, 10, 30, or 60 minutes.
- 2-day Pro trial started from onboarding or the paywall.
- Two one-time Pro purchases: Lifetime and Supporter Lifetime. Both unlock the
  same features.
- Accessibility is required for locking.
- KikiAuthorization opens the Accessibility setup path from onboarding and
  Settings.
- KikiCommerceKit-backed access, paywall, purchase, and restore flow.

## Architecture

- `App/`: app lifecycle, AppKit glue, and Kiki wiring.
- `Core/`: pure product rules that can be tested from CLI without launching the app.
- `Features/`: menu, settings, onboarding, and paywall surfaces.
- `Platform/InputLock/`: `CGEventTap` wrapper, lock state, policy, permissions,
  timeout, and fallback unlock detection.
- `Shared/`: product config, plan copy, and overlay presentation copy.

See [Docs/PRD.md](Docs/PRD.md) and [Docs/Architecture.md](Docs/Architecture.md).

## Run

```sh
./script/build_and_run.sh
```

The script stages the built app at `dist/CatKeyboardLock.app`. Grant macOS
privacy permissions to that staged app to avoid Xcode DerivedData path churn.
When testing privacy permissions, avoid running the app from Xcode at the same
time; Xcode launches a separate DerivedData copy under LLDB.

Useful variants:

```sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
```

## Test

Core rule check:

```sh
./script/catlock_core.sh evaluate --access trial --accessibility denied --keyboard on
./script/catlock_core.sh matrix
```

UI smoke screenshot:

```sh
./script/catlock_ui.sh smoke
```

App integration:

```sh
xcodebuild test -project CatKeyboardLock.xcodeproj \
  -scheme CatKeyboardLock \
  -destination 'platform=macOS,arch=arm64'
```

See [Docs/Testing.md](Docs/Testing.md) for the test layers and release smoke flow.
