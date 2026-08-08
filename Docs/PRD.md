# Product Requirements - Cat Keyboard Lock

Cat Keyboard Lock is a macOS menu bar utility that temporarily blocks keyboard
or mouse-click input to prevent accidental interaction from cats, children, or
cleaning. It is free forever: no trial, subscription, account, or in-app
purchase is required.

## Product behavior

- Menu bar actions lock and unlock input.
- Keyboard is blocked by default; click blocking is optional.
- Lock duration is 5, 10, 30, or 60 minutes, with a failsafe timeout.
- Trigger Corner can toggle the existing lock/unlock flow.
- First launch offers skippable Accessibility and recovery onboarding.
- An optional developer tip jar appears in About, on the last onboarding step,
  and in the menu bar after ten completed locks. It unlocks nothing, never
  interrupts, and can be dismissed for good.

## Safety and privacy

The app requires Accessibility to filter input through `CGEventTap`. The event
tap exists only while locked. The app does not store or transmit key contents,
click locations, or pointer coordinates, and it collects no analytics.

## Out of scope

AI recognition, root helpers, DriverKit, IOHID, system extensions, accounts,
subscriptions, purchases, and payment processing.
