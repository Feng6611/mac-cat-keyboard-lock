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
var frontmostAppWindowID: Int?

for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let title = window[kCGWindowName as String] as? String ?? ""
    guard owner == ownerName,
          let id = window[kCGWindowNumber as String] as? Int else {
        continue
    }

    if title == targetTitle {
        print(id)
        exit(0)
    }

    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    let bounds = window[kCGWindowBounds as String] as? [String: Any]
    let width = bounds?["Width"] as? Double ?? 0
    let height = bounds?["Height"] as? Double ?? 0
    if frontmostAppWindowID == nil, layer == 0, width > 100, height > 100 {
        frontmostAppWindowID = id
    }
}

// Window titles may be redacted when the invoking terminal does not have
// Screen Recording permission. CGWindowList is front-to-back, so the first
// normal app window is the visible scene (or its frontmost attached sheet).
if let frontmostAppWindowID {
    print(frontmostAppWindowID)
    exit(0)
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
  if ! /usr/sbin/screencapture -x -l "$window_id" "$output"; then
    echo "Window was found, but macOS denied capture. Grant Screen Recording permission to the invoking terminal or Codex app." >&2
    return 1
  fi
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
        -CatKeyboardLock.Onboarding.v1 NO \
        --ui-smoke-onboarding
      ;;
    settings-lock)
      run_scene "$scene" "Lock" "$SCREENSHOT_DIR/settings-lock.png" \
        -CatKeyboardLock.Onboarding.v1 YES \
        --ui-smoke-settings lock
      ;;
    settings-system)
      run_scene "$scene" "System" "$SCREENSHOT_DIR/settings-system.png" \
        -CatKeyboardLock.Onboarding.v1 YES \
        --ui-smoke-settings system
      ;;
    settings-about)
      run_scene "$scene" "About" "$SCREENSHOT_DIR/settings-about.png" \
        -CatKeyboardLock.Onboarding.v1 YES \
        --ui-smoke-settings about
      ;;
    paywall)
      run_scene "$scene" "About" "$SCREENSHOT_DIR/paywall.png" \
        -CatKeyboardLock.Onboarding.v1 YES \
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
    -CatKeyboardLock.Onboarding.v1 NO \
    --ui-smoke-onboarding
  run_scene settings-lock "Lock" "$SCREENSHOT_DIR/settings-lock.png" \
    -CatKeyboardLock.Onboarding.v1 YES \
    --ui-smoke-settings lock
  run_scene settings-system "System" "$SCREENSHOT_DIR/settings-system.png" \
    -CatKeyboardLock.Onboarding.v1 YES \
    --ui-smoke-settings system
  run_scene settings-about "About" "$SCREENSHOT_DIR/settings-about.png" \
    -CatKeyboardLock.Onboarding.v1 YES \
    --ui-smoke-settings about
  run_scene paywall "About" "$SCREENSHOT_DIR/paywall.png" \
    -CatKeyboardLock.Onboarding.v1 YES \
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
