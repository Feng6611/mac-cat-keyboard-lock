# Decision Log

## 2026-08-08 — Free forever with optional external support

- Remove the app-managed trial, Pro access state, paywall, StoreKit/RevenueCat
  integration, product identifiers, and paid debug controls.
- Keep all locking behavior available indefinitely.
- Add `https://buymeacoffee.com/kkuk` as an optional About-page support link.
- Finish onboarding after the lock/unlock practice instead of showing a paywall.

Why: a focused utility with a clear safety model is easier to understand and
review when its core behavior is available without payment or account state.
