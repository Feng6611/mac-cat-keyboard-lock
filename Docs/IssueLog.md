# Issue Log

## I-001 — Commerce plan identity is still a fixed yearly/lifetime enum

Status: Resolved 2026-07-05

`CommercePlan` is now an open, hashable string identity. Cat maps `lifetime`
and `supporterLifetime` without semantic aliases; RevenueCat offering and
entitlement mapping resolve through configured product identifiers.

## I-002 — Cat has not adopted the high-level Settings and Onboarding flows

Status: Resolved 2026-07-05

Settings now uses `KikiSettingsCoordinator` /
`KikiStandardAboutPane`; onboarding uses `KikiOnboardingCoordinator`.
Cat-specific permission content, paywall content, Pro skip policy, and legacy
completion migration remain in the app.

## I-003 — Real purchase and restore require manual release verification

Status: Open — release gate

Automated tests cover offering mapping, transaction workflow, error feedback,
and completion callbacks with test clients. A signed build with a configured
RevenueCat API key must still verify real purchase, cancellation, activation
refresh, restore-with-purchase, and restore-without-purchase before release.

## I-004 — Phase B/C review regressions

Status: Resolved 2026-07-05

Resolved the legacy onboarding completion migration, existing-Pro skip rule,
Paywall offering load, transaction serialization, visible feedback, host
completion callbacks, settings-sheet dismissal, and entitled CTA routing.
