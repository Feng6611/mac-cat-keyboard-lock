# Product Requirements - cat keyboard lock

## Purpose

`cat keyboard lock` is a macOS menu bar utility that temporarily blocks input
after the user manually turns it on. Its first use case is preventing accidental
typing or clicks from cats, children, or keyboard cleaning.

The app prioritizes safe recovery over aggressive blocking. If the app quits,
crashes, loses its event tap, or reaches the timeout, normal system input should
recover naturally.

## Target User

Mac users who occasionally need to protect the current session from accidental
keyboard input while keeping the machine awake and visible.

## MVP Scope

- Menu bar-only app with manual `Lock Keyboard` and `Unlock`.
- Default policy locks keyboard events only.
- Settings exposes two input types: keyboard and clicks.
- Settings can tune lock feedback with five levels. The default is level 4.
- Settings can enable an optional trigger corner when access is active. When
  enabled, resting the pointer in the selected screen corner briefly toggles the
  normal lock/unlock flow.
- Lock duration is selectable: 5, 10, 30, or 60 minutes. The default is
  10 minutes.
- First launch shows a lightweight, skippable onboarding window covering the
  lock model, Accessibility setup, and recovery. Its practice blocks only the
  keyboard for at most 60 seconds, keeps pointer clicks available, and advances
  automatically when the user dwells in the default trigger corner to lock and
  then returns to it to unlock. There are no manual lock/unlock buttons in the
  practice. Completing both corner actions enables that trigger corner; skipping
  preserves the prior setting. The final onboarding step presents the same
  paywall sheet used by Settings About. A one-time 2-day app-managed Pro trial
  starts automatically on first launch, never renews, and never charges the user.
- Trial and Pro unlock the full input-lock feature set. When the trial has
  expired, new lock attempts open the paywall instead of starting a lock.
- Settings exposes Pro status in About. Clicking the About status row opens the
  app-owned paywall sheet for upgrade, restore, and active Pro status. Purchase
  controls are not duplicated in other Settings tabs.
- Pro is sold through Apple In-App Purchase and one RevenueCat offering with two
  non-consumable packages that unlock the same `cat keyboard lock Pro`
  entitlement: Lifetime (`dev.kkuk.catkeyboardlock.pro.lifetime`) with a target
  US price of `$6.99`, and Support Developer Lifetime
  (`dev.kkuk.catkeyboardlock.pro.supporter`) with a target US price of `$10.99`.
  Lifetime is selected by default. App Store Connect owns authoritative
  localized prices.
- Upgrade surfaces remain app-owned Kiki views. They consume RevenueCat
  offering metadata and route purchase/restore through `KikiRevenueCat`;
  RevenueCat Paywall and Customer Center UI are intentionally not integrated.
- Purchase, restore, and CustomerInfo changes refresh the single
  `KikiAccessManager` before the app makes a routing decision.
- Uses `CGEventTap` as an active filter only while locked.
- Requires Accessibility for locking.
- Uses KikiCommerceKit for provider-neutral trial/access state, RevenueCat
  product loading, purchase, restore, entitlement refresh, and reusable Paywall
  orchestration. The app links the `RevenueCat` SDK directly only for typed
  CustomerInfo access needed by app-owned account logic.

## Explicitly Out of Scope

- AI recognition, device-specific blocking, Touch ID, root helper tools,
  DriverKit, IOHID, and system extensions.
- Recording key contents, uploading input data, analytics, or telemetry.
- Shipping/distribution setup such as notarization, Sparkle, or DMG packaging.

## Product Behavior

- When unlocked, the app does not install an active input filter.
- When access is active trial or Pro, lock entries start the normal lock flow.
- When access is trial-not-started or expired, lock entries open the paywall.
- When the trigger corner is enabled and access is active or input is already
  locked, the app polls pointer position with a lightweight timer and toggles
  the existing lock/unlock flow only after the pointer dwells in the selected
  corner. The trigger corner does not install an event tap, suppress input, or
  add another privacy permission.
- When locked, selected keyboard and click events are suppressed by returning
  `nil` from the event tap callback.
- If a trial expires during an active lock, the current lock is not interrupted;
  menu-bar unlock, trigger-corner unlock when configured, timeout, and quitting
  the app remain available.
- Lock and unlock transitions show KikiOverlay global orange screen-edge
  breathing as visual feedback. Trigger moments use a stronger short burst,
  the persistent locked state keeps a subtle visible breathing rhythm, toasts
  last 5 seconds, and warning flashes are reserved for disabled input filters.
- The menu bar item uses one stable keyboard symbol. Locked and unlocked are
  represented as active/inactive and tinted/untinted states of that symbol, not
  unrelated icons.
- Click suppression may make menu-bar unlock unavailable. Settings must explain
  that the selected timeout always restores input and that an enabled trigger
  corner remains available because pointer movement is not blocked.
- If event tap creation fails, the app shows a permission or failure state
  instead of pretending the system is locked.
- If Accessibility is missing, onboarding and Settings route setup through
  `KikiAuthorization`; closing onboarding does not block Settings, Quit, or
  later permission setup.

## Privacy

- Input is intercepted only during an active lock session.
- Trigger corner monitoring reads the current pointer position only to decide
  whether to start locking; it does not persist pointer coordinates.
- The app does not persist key codes, typed text, or click locations.
- No input data leaves the device.

## Success Criteria

- A user can launch the app, use the automatically started trial, lock the
  keyboard from the menu bar, and unlock it from the menu bar with default
  settings.
- The app records one stable trial start date on first launch and never restarts
  the trial after expiration.
- Expired access opens the paywall for new lock attempts.
- Onboarding proves a real keyboard-only lock and trigger-corner recovery. The
  practice automatically restores input after 60 seconds if the second corner
  action is not completed.
- The app releases the lock after the selected lock duration.
- If enabled, the selected trigger corner toggles lock state after a brief dwell
  and avoids repeated triggers while the pointer remains in the corner.
- Quitting or crashing the app removes the filter because the event tap is owned
  by the app process.
- Unit tests cover menu mapping, lock policy masks, onboarding practice policy,
  trigger corner geometry/dwell behavior, and timeout behavior.
