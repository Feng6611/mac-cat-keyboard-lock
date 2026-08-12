# Product Requirements - Cat Keyboard Lock

Cat Keyboard Lock is a macOS menu bar utility that temporarily blocks keyboard
input to prevent accidental interaction from cats, children, or cleaning. It is
free: no trial, subscription, account, or in-app purchase is required.

## Product behavior

- Menu bar actions lock and unlock the keyboard.
- Pointer controls remain available for recovery.
- Lock duration is 5, 10, 30, or 60 minutes, with a failsafe timeout.
- Trigger Corner can toggle the existing lock/unlock flow.
- First launch offers skippable Accessibility and recovery onboarding.
- About links to the developer profile and offers one optional action: Star on
  GitHub.

## Safety and privacy

The app requires Accessibility to filter input through `CGEventTap`. The event
tap exists only while locked. The app does not store or transmit key contents,
pointer coordinates, or analytics.

## Out of scope

AI recognition, root helpers, DriverKit, IOHID, system extensions, accounts,
subscriptions, purchases, and payment processing.
