# Ticket 1: Set Log Screen as Default Tab

**Priority:** High (UX improvement)  
**Risk:** Very Low  
**Effort:** ~5 minutes  
**Status:** ⬜ Pending  

---

## Context

The app currently opens to the Dashboard tab (index 0). User research and design principles suggest the Log tab should be the default since it's the primary user action — users open the app to log food, not to view their dashboard.

From `issues.txt`:
> the log screen should be the default tab

---

## Current State

**File:** `lib/app.dart:99`

```dart
int _currentIndex = 0;  // Dashboard is default
```

The bottom navigation has 4 tabs:
- Index 0: Dashboard
- Index 1: Log ← should be default
- Index 2: Bodyweight
- Index 3: Goals

---

## Required Changes

**File:** `lib/app.dart`

**Line 99:** Change `_currentIndex` from `0` to `1`

```dart
int _currentIndex = 1;  // Log screen is default
```

That's the only change required.

---

## Acceptance Criteria

- [ ] App opens to Log tab by default on fresh launch
- [ ] All 4 tabs remain accessible via bottom navigation
- [ ] Tab state persists correctly when switching between tabs
- [ ] No test failures
- [ ] `flutter analyze` passes with zero issues

---

## Testing

### Manual Testing
1. Launch app from cold start
2. Verify Log tab is visible (not Dashboard)
3. Navigate to each tab, verify all work correctly
4. Restart app, verify Log tab is still default

### Automated Testing
- No existing tests assert on initial tab state
- No test updates required

### Commands
```bash
flutter analyze
flutter test
flutter run  # manual verification
```

---

## Files to Modify

| File | Lines Changed | Type |
|------|---------------|------|
| `lib/app.dart` | 1 | Production |

**Total:** 1 line of production code, 0 test lines

---

## Implementation Notes

- This is a trivial change with zero logic impact
- No migration needed (app not yet published)
- Safe to ship independently
- No dependencies on other tickets

---

## References

- `DISCOVERY.md` — Issue 4 section
- `lib/app.dart:99-110` — App shell implementation
- `issues.txt:4` — Original issue
