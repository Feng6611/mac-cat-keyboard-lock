#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/cli"
BINARY="$BUILD_DIR/catlock-core"

mkdir -p "$BUILD_DIR"

/usr/bin/swiftc \
  "$ROOT_DIR/CatKeyboardLock/Core/CatKeyboardLockCore.swift" \
  "$ROOT_DIR/script/CatLockCoreCLI.swift" \
  -o "$BINARY"

exec "$BINARY" "$@"
