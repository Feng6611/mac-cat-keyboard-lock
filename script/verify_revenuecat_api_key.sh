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

if [[ "$configuration" == "Release" && "$key" != appl_* ]]; then
  echo "error: Release requires a RevenueCat Apple public SDK key beginning with appl_."
  exit 1
fi

if [[ "$configuration" != "Release" && "$key" != test_* && "$key" != appl_* ]]; then
  echo "error: RevenueCat key must be a Test Store key (test_) or Apple public SDK key (appl_)."
  exit 1
fi

echo "RevenueCat SDK key validated for $configuration."
