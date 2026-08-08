# Cat Keyboard Lock Testing

The free release is verified at three boundaries: deterministic Core rules,
Xcode integration, and manual macOS safety behavior.

## Feature inventory

| Feature | Entry point | Verification |
| --- | --- | --- |
| Keyboard/click locking | Menu bar | Core tests, Xcode tests, manual smoke |
| Accessibility permission | Onboarding / Settings | Xcode tests, manual grant/deny |
| Timeout and recovery | Lock session | Controller tests, manual timeout/quit |
| Trigger corner | Settings | Lifecycle tests, manual pointer dwell |
| Free forever behavior | Menu / About | Core tests, no purchase/trial entries |
| Optional support | About | About UI link resolves to Buy Me a Coffee |

## Commands

```sh
git diff --check
./script/catlock_core.sh matrix
xcodebuild test -project CatKeyboardLock.xcodeproj \
  -scheme CatKeyboardLock \
  -destination 'platform=macOS,arch=arm64'
./script/catlock_ui.sh smoke
```

Core evaluation always uses `--access free`; access is retained as a pure
value in the test boundary so lock routing stays deterministic.

UI smoke covers onboarding, Lock, System, and About. It does not grant
Accessibility, lock real input, or simulate a donation.

## Manual release smoke

1. Grant and revoke Accessibility, then confirm the app explains the state.
2. Lock keyboard input, unlock from the menu bar, and wait for timeout recovery.
3. Enable Clicks and Trigger Corner, then verify pointer recovery remains usable.
4. Open About and confirm the optional support link opens
   `https://buymeacoffee.com/kkuk`.
