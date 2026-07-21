# Cat Lock Privacy Policy

Last updated: 2026-07-21

Cat Lock is designed to keep input data on your Mac. This policy describes
what the app processes and what it does not collect.

## Input events

When you activate a lock, Cat Lock uses macOS Accessibility APIs (`CGEventTap`)
to suppress the selected keyboard and, optionally, click events. Input is
processed locally for the active lock only. Cat Lock does not read, record,
store, upload, or sell typed text, key codes, click locations, or pointer
coordinates.

When the lock is inactive, Cat Lock does not install an active input filter.
Trigger-corner mode checks the current pointer position only while that
setting is enabled; the position is not persisted.

## Local settings

Settings such as lock duration, selected input types, trigger corner, feedback
level, and trial state are stored locally in macOS preferences. No clipboard
history or input log is written to disk.

## Purchases

Purchases are handled by Apple and validated through RevenueCat. Those services
may process the Apple account, device, transaction, and entitlement metadata
needed to complete a purchase or restore. Cat Lock does not receive payment
card details and does not use purchase data for advertising or analytics.

## Analytics and support

Cat Lock does not include analytics, telemetry, session recording, or crash
reporting. Support is user-initiated through the repository issue tracker or
the contact address below.

## Contact

For privacy questions, open an issue at
<https://github.com/Feng6611/mac-cat-keyboard-lock/issues> or email
<fchen6611@gmail.com>.
