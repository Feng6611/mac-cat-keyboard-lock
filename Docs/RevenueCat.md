# RevenueCat setup

Cat Keyboard Lock uses `KikiCommerceKit` for provider-neutral access/trial
state, offering loading, purchases, restores, and the app-owned Kiki paywall.
The app also links the `RevenueCat` SDK product for typed CustomerInfo access.
RevenueCatUI, RevenueCat Paywall, and Customer Center pages are not integrated.

## Local SDK key

Copy `Config/LocalSecrets.xcconfig.example` to
`Config/LocalSecrets.xcconfig` and set:

```xcconfig
CATLOCK_REVENUECAT_API_KEY = test_or_appl_public_sdk_key
```

The local file is gitignored. Debug accepts RevenueCat Test Store keys. Release
rejects missing, placeholder, and `test_` keys; use the Apple public SDK key
from the production RevenueCat app before archiving.

## Dashboard and store configuration

1. Create or select the macOS app with bundle ID `dev.kkuk.catkeyboardlock`.
2. Create the entitlement `cat keyboard lock Pro`.
3. Create/import these products and attach both to that entitlement:

   | Product | Type | Identifier |
   | --- | --- | --- |
   | Lifetime | Non-consumable | `dev.kkuk.catkeyboardlock.pro.lifetime` |
   | Support Developer Lifetime | Non-consumable | `dev.kkuk.catkeyboardlock.pro.supporter` |

4. Set the target US storefront prices to `$6.99` and `$10.99`; configure other
   storefronts and localization in App Store Connect. There is no subscription
   group because both products are non-consumables.
5. Create the `default` offering with a lifetime package and a custom supporter
   lifetime package mapped to the matching products. Make `default` current.
6. Configure App Store Connect agreements, tax/banking, product metadata,
   localization, availability, and review screenshots before release.

RevenueCat Test Store products with the same identifiers are sufficient for
local Debug validation. Real App Store prices and periods remain dashboard/store
configuration and are never hardcoded as authoritative app data. The code's
`$6.99` and `$10.99` values are fallback copy only.

## Trial ownership

The one-time 2-day Pro trial is app-managed by `KikiCommerceCore` and starts on
first launch. Apple introductory free trials apply to auto-renewable
subscriptions, so they cannot be attached to these lifetime non-consumables.
Purchases and restores still run entirely through Apple's StoreKit payment
system via RevenueCat.

## Runtime flow

1. `AppComposition` constructs one `KikiAccessManager` with the app's
   `RevenueCatConfiguration`.
2. Lifecycle calls `await accessManager.refresh()` before automatic
   onboarding decisions.
3. Settings/About or gated lock actions route to `KikiAccessPaywallSheet`.
4. KikiRevenueCat loads the current/default offering and performs
   purchases/restores through the RevenueCat SDK.
5. Active `cat keyboard lock Pro` CustomerInfo unlocks Pro, and the SDK
   delegate delivers later CustomerInfo changes into the same manager.
6. App-owned account logic may request a read-only
   `CatKeyboardLockCustomerInfoSnapshot`; it must not mirror mutable access
   state outside `KikiAccessManager`.

## Verification

```sh
./script/verify_revenuecat_api_key.sh
./script/catlock_core.sh matrix
xcodebuild test -project CatKeyboardLock.xcodeproj \
  -scheme CatKeyboardLock \
  -destination 'platform=macOS,arch=arm64'
./script/catlock_ui.sh smoke
```

Before release, replace the test key and manually verify offering load, both
purchases, cancellation, restore with and without entitlement, trial and paid
relaunch persistence, lifetime access, and offline behavior.
