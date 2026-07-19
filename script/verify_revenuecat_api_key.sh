#!/bin/zsh

set -euo pipefail

key="$(printenv CATLOCK_REVENUECAT_API_KEY || true)"
configuration="$(printenv CONFIGURATION || echo Debug)"
root="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "$key" && -f "$root/Config/LocalSecrets.xcconfig" ]]; then
  key="$(sed -n 's/^[[:space:]]*CATLOCK_REVENUECAT_API_KEY[[:space:]]*=[[:space:]]*//p' "$root/Config/LocalSecrets.xcconfig" | tail -1 | tr -d '[:space:]')"
fi

if [[ -z "$key" || "$key" == "test_or_appl_public_sdk_key" ]]; then
  echo "error: CATLOCK_REVENUECAT_API_KEY is missing. Configure Config/LocalSecrets.xcconfig or CI build settings."
  exit 1
fi

if [[ "$key" != appl_* ]]; then
  echo "error: Cat Keyboard Lock uses Apple Sandbox for Debug and requires an appl_ public SDK key in every App Store configuration."
  exit 1
fi

if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${INFOPLIST_PATH:-}" ]]; then
  built_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
  if [[ ! -f "$built_plist" ]]; then
    echo "error: Built product Info.plist is missing at $built_plist."
    exit 1
  fi

  embedded_key="$(/usr/libexec/PlistBuddy -c 'Print :CatKeyboardLockRevenueCatAPIKey' "$built_plist" 2>/dev/null || true)"
  if [[ "$embedded_key" != "$key" ]]; then
    echo "error: Built CatKeyboardLock.app does not contain the configured RevenueCat API key."
    exit 1
  fi

  embedded_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$built_plist" 2>/dev/null || true)"
  if [[ "$embedded_bundle_id" != "dev.kkuk.catkeyboardlock" ]]; then
    echo "error: Built product has unexpected bundle identifier: ${embedded_bundle_id:-<missing>}."
    exit 1
  fi

  echo "Verified RevenueCat configuration in the built CatKeyboardLock.app."
fi

echo "RevenueCat SDK key validated for $configuration."
