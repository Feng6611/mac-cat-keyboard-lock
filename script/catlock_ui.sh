#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CatKeyboardLock"
APP_OWNER_NAME="cat keyboard lock"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
SCREENSHOT_DIR="${CATLOCK_UI_SCREENSHOT_DIR:-$ROOT_DIR/build/ui-smoke}"

usage() {
  cat <<'EOF'
usage:
  script/catlock_ui.sh onboarding
  script/catlock_ui.sh settings-lock
  script/catlock_ui.sh settings-system
  script/catlock_ui.sh settings-about
  script/catlock_ui.sh paywall
  script/catlock_ui.sh smoke

The command builds the app, opens the requested UI scene, and captures the
matching app window under build/ui-smoke/.
EOF
}

build_app() {
  "$ROOT_DIR/script/build_and_run.sh" --build-only
}

stop_app() {
  /usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  sleep 0.3
}

launch_app() {
  /usr/bin/open -n "$APP_BUNDLE" --args "$@"
}

window_id_for_title() {
  local title="$1"
  CATLOCK_WINDOW_TITLE="$title" CATLOCK_OWNER_NAME="$APP_OWNER_NAME" /usr/bin/swift -e '
import CoreGraphics
import Foundation

let targetTitle = ProcessInfo.processInfo.environment["CATLOCK_WINDOW_TITLE"] ?? ""
let ownerName = ProcessInfo.processInfo.environment["CATLOCK_OWNER_NAME"] ?? ""
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []

for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let title = window[kCGWindowName as String] as? String ?? ""
    if owner == ownerName && title == targetTitle, let id = window[kCGWindowNumber as String] as? Int {
        print(id)
        exit(0)
    }
}
exit(1)
'
}

capture_window() {
  local title="$1"
  local output="$2"
  local window_id=""

  for _ in $(seq 1 30); do
    if window_id="$(window_id_for_title "$title" 2>/dev/null)"; then
      break
    fi
    sleep 0.2
  done

  if [[ -z "$window_id" ]]; then
    echo "Could not find Cat Keyboard Lock window titled '$title'." >&2
    return 1
  fi

  mkdir -p "$(dirname "$output")"
  /usr/sbin/screencapture -x -l "$window_id" "$output"
  echo "$output"
}

run_scene() {
  local scene="$1"
  local title="$2"
  local output="$3"
  shift 3

  stop_app
  launch_app "$@"
  capture_window "$title" "$output"
}

run_single_scene() {
  local scene="$1"

  build_app
  case "$scene" in
    onboarding)
      run_scene "$scene" "Welcome" "$SCREENSHOT_DIR/onboarding.png" \
        -CatKeyboardLock.Pro.hasCompletedOnboarding NO \
        --ui-smoke-onboarding
      ;;
    settings-lock)
      run_scene "$scene" "Lock" "$SCREENSHOT_DIR/settings-lock.png" \
        -CatKeyboardLock.Pro.hasCompletedOnboarding YES \
        --ui-smoke-settings lock
      ;;
    settings-system)
      run_scene "$scene" "System" "$SCREENSHOT_DIR/settings-system.png" \
        -CatKeyboardLock.Pro.hasCompletedOnboarding YES \
        --ui-smoke-settings system
      ;;
    settings-about)
      run_scene "$scene" "About" "$SCREENSHOT_DIR/settings-about.png" \
        -CatKeyboardLock.Pro.hasCompletedOnboarding YES \
        --ui-smoke-settings about
      ;;
    paywall)
      run_scene "$scene" "Upgrade" "$SCREENSHOT_DIR/paywall.png" \
        -CatKeyboardLock.Pro.hasCompletedOnboarding YES \
        --ui-smoke-paywall
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

run_smoke() {
  build_app
  run_scene onboarding "Welcome" "$SCREENSHOT_DIR/onboarding.png" \
    -CatKeyboardLock.Pro.hasCompletedOnboarding NO \
    --ui-smoke-onboarding
  run_scene settings-lock "Lock" "$SCREENSHOT_DIR/settings-lock.png" \
    -CatKeyboardLock.Pro.hasCompletedOnboarding YES \
    --ui-smoke-settings lock
  run_scene settings-system "System" "$SCREENSHOT_DIR/settings-system.png" \
    -CatKeyboardLock.Pro.hasCompletedOnboarding YES \
    --ui-smoke-settings system
  run_scene settings-about "About" "$SCREENSHOT_DIR/settings-about.png" \
    -CatKeyboardLock.Pro.hasCompletedOnboarding YES \
    --ui-smoke-settings about
  run_scene paywall "Upgrade" "$SCREENSHOT_DIR/paywall.png" \
    -CatKeyboardLock.Pro.hasCompletedOnboarding YES \
    --ui-smoke-paywall
}

command="${1:-}"
case "$command" in
  onboarding|settings-lock|settings-system|settings-about|paywall)
    run_single_scene "$command"
    ;;
  smoke)
    run_smoke
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac
