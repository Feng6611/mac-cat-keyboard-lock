# Decision Log

## 2026-07-14 — Two Apple lifetime products with one Pro entitlement

- Keep the stable product identifiers
  `dev.kkuk.catkeyboardlock.pro.lifetime` and
  `dev.kkuk.catkeyboardlock.pro.supporter` as Apple non-consumables.
- Target `$6.99` for Lifetime and `$10.99` for Support Developer Lifetime in the
  US storefront. Select Lifetime by default and attach both products to the
  same `cat keyboard lock Pro` entitlement.
- Start the stable, app-managed 2-day trial automatically on first launch.
  Apple introductory trials are not used because the products are lifetime
  non-consumables rather than auto-renewable subscriptions.
- Keep purchase, restore, and payment confirmation in Apple's StoreKit system
  through RevenueCat, while retaining Cat's app-owned Kiki purchase UI.

Why: both prices represent the same permanent Pro access, while the supporter
option lets users voluntarily contribute more without creating a second access
level or subscription lifecycle.

## 2026-07-14 — RevenueCat SDK-only with app-owned Kiki purchase UI

- Link only the `RevenueCat` product from the same exact `purchases-ios-spm`
  version already selected by KikiCommerceKit. Do not link RevenueCatUI.
- Keep the app-owned `KikiAccessPaywallSheet` for the two lifetime products;
  offering loading, purchase, and restore continue through KikiRevenueCat.
- Expose typed CustomerInfo snapshots for app-owned logic and treat
  `CustomerInfo.entitlements["cat keyboard lock Pro"]?.isActive` as the direct
  SDK entitlement check. Keep `KikiAccessManager` as the only observable access
  source.
- Inject the public SDK key through xcconfig. Permit the supplied `test_` key
  only in Debug and require a production `appl_` key for Release.
- RevenueCat Paywall and Customer Center pages are intentionally out of scope;
  visible purchase and account logic remains app-owned.

Why: Cat needs RevenueCat transport and entitlement support without delegating
its product UI or routing decisions to RevenueCat-owned pages.

## 2026-07-10 — Reference App composition and authoritative startup

- Split the former all-purpose AppDelegate into immutable `AppDefinition`,
  construction-only `AppComposition`, action-only `AppRouter`, and runtime
  `LifecycleCoordinator`. Keep the SwiftUI App and delegate as thin adapters.
- Make the existing pure `CatKeyboardLockCore.evaluate` result the production
  routing source. Permission and input-policy branches may no longer be ignored
  or replaced with hard-coded accessibility state in menu construction.
- Wait for authoritative Commerce readiness before automatic onboarding. An
  explicit launch scene is routed exactly once and never followed by the normal
  automatic onboarding branch.
- Keep unlock and teardown outside access gating so an entitlement change can
  never strand an active input lock.

## D-001 — One access source of truth across Cat and Commerce

Date: 2026-07-05

Decision: Cat Keyboard Lock holds one `KikiProAccessManager` at its composition
root. KikiCommerceCore owns reusable access/trial calculation,
KikiRevenueCat owns provider transport, and KikiCommercePresentation owns
offering and transaction orchestration. Cat supplies product identifiers,
plans, copy, migration rules, and feature gates.

Why: The deleted `CatKeyboardLockProStatusManager` mirrored Commerce state and
created two owners for purchase, trial, and entitlement behavior. Directly
observing one manager keeps menu, Settings, onboarding, and trigger-corner
gating consistent without moving Cat-specific lock policy into a package.

Consequences:

- App-local entitlement snapshots must remain pure read models, not a second
  mutable manager.
- Paywall success, failure, offering loading, and busy state are tested in
  KikiCommercePresentation.
- Onboarding completion remains independent of paid access, while Cat owns
  legacy-key migration and the rule that existing Pro users skip automatic
  onboarding.

## D-002 — One package identity during integration, tagged HTTPS for release

Date: 2026-07-05

Decision: While Cat, KikiCommerceKit, and Kiki_mackit are changed together,
both Cat and Commerce use the same adjacent local Kiki checkout. Before
release, Kiki is tagged first, Commerce switches to that tagged HTTPS
requirement and is tagged, then Cat switches to both tagged dependencies.

Why: Mixing Cat's local Kiki reference with Commerce's floating remote Kiki
dependency creates two references to the same SwiftPM identity. SwiftPM warns
today and will reject that graph in a future version.

Consequences:

- Development dependency audit allows the local graph with warnings.
- Release dependency audit rejects every local path and floating branch.
- No package manifest may silently depend on a developer-specific absolute
  path.

## D-003 — Kit coordinators own mechanics; Cat owns product policy

Date: 2026-07-05

Decision: Settings uses `KikiSettingsCoordinatorView` and
`KikiStandardAboutPane`; onboarding uses `KikiOnboardingCoordinator` with
custom Cat steps. The app retains only route flags, copy, permission actions,
legacy completion migration, and the policy for whether onboarding should
appear.

Why: Window lookup, tab navigation, completion writes, close semantics, and
page progression are reusable mechanics. Permission rationale, product links,
Pro skip behavior, and the trial handoff are Cat product decisions.

Consequences:

- Settings visibility and close act on one registered native window.
- Closing Cat onboarding is explicitly configured as completion.
- Paywall behavior remains composed through CommercePresentation rather than
  being pulled into the onboarding coordinator.
