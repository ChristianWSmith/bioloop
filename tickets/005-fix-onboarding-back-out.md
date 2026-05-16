# Ticket 5: Fix onboarding discard confirms leaving a black screen

**Issue:** #5  
**Priority:** Medium  
**Effort:** 2 lines  
**File:** `lib/features/onboarding/onboarding_screen.dart`

## Context

When the user is in onboarding and presses the system back button, a discard confirmation dialog appears. If they tap "Leave", the app navigates to a black screen instead of closing.

### Root cause

`OnboardingScreen` is returned as the `home` of `MaterialApp` in `App._buildHome()` (`app.dart:79`). It is the only route in the navigation stack.

When the user confirms discard, the handler runs:
```dart
if (shouldPop == true && mounted) {
  setState(() => _canPop = true);
  Navigator.of(context).pop();
}
```

`Navigator.pop()` removes the only route, leaving the navigation stack empty. Flutter displays the default Scaffold background color (black/dark grey by default).

The correct behavior is to close the app entirely — the user explicitly chose not to complete onboarding.

### Fix

Replace `Navigator.of(context).pop()` with `SystemNavigator.pop()` from `package:flutter/services.dart`. This exits the application cleanly.

## Acceptance criteria

- [ ] Start onboarding (fresh install or data reset)
- [ ] Press system back button → discard dialog appears
- [ ] Tap "Stay" → remains on onboarding, no progress lost
- [ ] Tap "Leave" → app closes (returns to home screen / app switcher)
- [ ] Re-launch app → onboarding starts fresh (not marked as completed)
- [ ] Normal onboarding flow (fill data → Save) → app transitions to main shell normally

## Testing

### Manual testing
1. Launch app after data reset → onboarding screen
2. Press system back → "Discard progress?" dialog
3. Tap "Leave" → app should close immediately
4. Re-launch → onboarding appears again
5. Complete onboarding (fill all fields → Save) → main app shell appears
6. From main app, press back → no dialog, no app close (standard navigation)

### Regression checks
- Normal onboarding completion (`_save()` → `widget.onComplete()`) is unaffected
- `_canPop` mechanism remains for edge cases where pop might be used
- No other `Navigator.pop()` calls in onboarding need changing

## Implementation

```dart
// lib/features/onboarding/onboarding_screen.dart
// Add import at top:
import 'package:flutter/services.dart';

// Lines 293-295, replace:
if (shouldPop == true && mounted) {
  setState(() => _canPop = true);
  Navigator.of(context).pop();
}
// With:
if (shouldPop == true && mounted) {
  SystemNavigator.pop();
}
```

Note: `_canPop = true` and the `PopScope` can be simplified since we no longer need to allow a normal pop. The `_canPop` state variable and the `setState` call can remain for safety but are no longer functionally needed.
