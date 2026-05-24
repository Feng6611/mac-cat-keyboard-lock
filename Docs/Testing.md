# Cat Keyboard Lock Testing

Cat Keyboard Lock uses three test layers. Keep each layer narrow so failures are easy to classify.

## Core CLI

Core tests cover product rules without launching the Mac app. Use this for access state, permission state, menu action naming, and lock request routing.

```bash
script/catlock_core.sh evaluate --access trial --accessibility denied --keyboard on
```

Expected output is JSON. The important fields are:

- `menuLockTitle`: the user-facing menu command.
- `lockRequestAction`: the next product action, such as `lock`, `openPermission`, or `openPaywall`.
- `warnings`: rule-level problems that should be visible in UI or logs.

Use this layer while building a feature and before changing UI.

## App Integration

App integration is still Xcode-native. It proves the app target builds, dependencies resolve, and the SwiftUI/AppKit wiring compiles with tests.

```bash
xcodebuild test -project CatKeyboardLock.xcodeproj -scheme CatKeyboardLock -destination 'platform=macOS,arch=arm64'
xcodebuild build -project CatKeyboardLock.xcodeproj -scheme CatKeyboardLock -configuration Debug -destination 'platform=macOS,arch=arm64'
```

Use this layer before every commit.

## UI CLI

UI smoke tests launch fixed scenes and capture screenshots for review. They do not grant system permissions, make purchases, or lock real input.

```bash
script/catlock_ui.sh onboarding
script/catlock_ui.sh settings-lock
script/catlock_ui.sh settings-system
script/catlock_ui.sh settings-about
script/catlock_ui.sh paywall
script/catlock_ui.sh smoke
```

Screenshots are written to `build/ui-smoke/`. Use this layer before release or after changing onboarding, settings, paywall, menu entry points, or Kiki component integration.

## Release Smoke

Before release, run:

1. Core CLI examples for access and permission states.
2. Full Xcode test.
3. Debug build.
4. UI CLI smoke screenshots.
5. Manual check only for dangerous paths: real Accessibility grant, real lock, unlock, timeout, purchase, and restore.
