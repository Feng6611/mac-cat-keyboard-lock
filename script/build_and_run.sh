#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
if [[ $# -gt 0 ]]; then
  shift
fi
APP_ARGS=("$@")
APP_NAME="CatKeyboardLock"
BUNDLE_ID="dev.kkuk.catkeyboardlock"
PROJECT_NAME="CatKeyboardLock.xcodeproj"
SCHEME_NAME="CatKeyboardLock"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/build/DerivedData"
BUILD_APP_BUNDLE="$DERIVED_DATA_DIR/Build/Products/Debug/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cd "$ROOT_DIR"

stop_running_app() {
  local pids pid ppid parent_command
  pids="$(pgrep -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" || true)"

  for pid in $pids; do
    ppid="$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ' || true)"
    parent_command="$(ps -p "$ppid" -o command= 2>/dev/null || true)"
    if [[ "$parent_command" == *"/debugserver"* ]]; then
      kill "$ppid" >/dev/null 2>&1 || true
    fi
    kill "$pid" >/dev/null 2>&1 || true
  done

  sleep 0.5
  for pid in $pids; do
    kill -9 "$pid" >/dev/null 2>&1 || true
  done
}

stop_running_app

xcodebuild \
  -project "$PROJECT_NAME" \
  -scheme "$SCHEME_NAME" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

rm -rf "$APP_BUNDLE"
mkdir -p "$DIST_DIR"
/usr/bin/ditto "$BUILD_APP_BUNDLE" "$APP_BUNDLE"
/usr/bin/xattr -dr com.apple.quarantine "$APP_BUNDLE" >/dev/null 2>&1 || true

open_app() {
  if [[ ${#APP_ARGS[@]} -gt 0 ]]; then
    /usr/bin/open -n "$APP_BUNDLE" --args "${APP_ARGS[@]}"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

case "$MODE" in
  --build-only|build)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify] [app args...]" >&2
    exit 2
    ;;
esac
