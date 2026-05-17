# BioLoop Issues — Implementation Checklist

**Created:** May 17, 2026  
**Source:** `issues.txt` (5 issues)  
**Discovery:** `DISCOVERY.md`  
**Tickets:** `tickets/` directory (5 tickets)

---

## Progress Overview

| Ticket | Issue | Priority | Status | Progress |
|--------|-------|----------|--------|----------|
| [001](#ticket-1-set-log-screen-as-default-tab) | Log screen default tab | High | ✅ Complete | 100% |
| [002](#ticket-2-clamp-calorie-targets-to-non-negative-values) | Clamp calorie targets | High | ✅ Complete | 100% |
| [003](#ticket-3-exclude-current-day-from-regression-calculation) | Exclude current day | Medium | ✅ Complete | 100% |
| [004](#ticket-4-apply-calorie-clamping-at-openfoodfacts-import-time) | Calorie clamping timing | High | ✅ Complete | 100% |
| [005](#ticket-5-improve-regression-algorithm--14-day-threshold--weight-stability-detection) | Regression improvements | Medium | ✅ Complete | 100% |

**Overall Progress:** 5/5 tickets complete (100%)

---

## Implementation Order

Recommended sequence (by risk and dependency):

```
1 → 2 → 3 → 4 → 5
│   │   │   │   │
│   │   │   │   └─ Most complex (algorithm change)
│   │   │   └───── User-facing bug fix
│   │   └───────── Data quality fix
│   └───────────── Safety fix
└───────────────── Trivial UX win
```

**Rationale:**
- Start with easy wins (Tickets 1-3) to build momentum
- Tackle user-facing bug (Ticket 4) before complex algorithm work
- End with algorithm improvements (Ticket 5) requiring most test validation

---

## Ticket 1: Set Log Screen as Default Tab

**File:** [`tickets/001-log-screen-default-tab.md`](tickets/001-log-screen-default-tab.md)  
**Priority:** High | **Risk:** Very Low | **Effort:** ~5 minutes

### Checklist

- [x] **Implementation**
  - [x] Change `_currentIndex` from `0` to `1` in `lib/app.dart:99`
  
- [x] **Testing**
  - [x] Run `flutter analyze` (must pass with 0 issues)
  - [x] Run `flutter test` (all tests must pass)
  - [x] Manual test: Launch app, verify Log tab is default
  
- [x] **Verification**
  - [x] All 4 tabs accessible via bottom navigation
  - [x] Tab state persists when switching
  - [x] No console errors

### Notes

```
[x] Start: May 17, 2026
[x] Complete: May 17, 2026
[x] Verified: May 17, 2026
```

---

## Ticket 2: Clamp Calorie Targets to Non-Negative Values

**File:** [`tickets/002-clamp-calorie-targets-non-negative.md`](tickets/002-clamp-calorie-targets-non-negative.md)  
**Priority:** High | **Risk:** Low | **Effort:** ~30 minutes

### Checklist

- [x] **Implementation**
  - [x] Add `targetCalories = max(0.0, targetCalories);` in `MacroTargets.compute()` after line 50
  - [x] Verify `dart:math` import exists (should already be there)
  
- [x] **Testing**
  - [x] Add test: "target calories clamped to 0 when deficit exceeds regression maintenance"
  - [x] Add test: "target calories clamped to 0 when Mifflin-St Jeor estimate is very low"
  - [x] Add test: "normal deficit produces correct positive target (not clamped)"
  - [x] Run `flutter analyze` (must pass with 0 issues)
  - [x] Run `flutter test test/providers/macro_targets_provider_test.dart`
  
- [x] **Verification**
  - [x] All existing tests pass
  - [x] New tests verify boundary conditions
  - [x] Target calories never negative in manual testing

### Notes

```
[x] Start: May 17, 2026
[x] Complete: May 17, 2026
[x] Verified: May 17, 2026
```

---

## Ticket 3: Exclude Current Day from Regression Calculation

**File:** [`tickets/003-exclude-current-day-regression.md`](tickets/003-exclude-current-day-regression.md)  
**Priority:** Medium | **Risk:** Low | **Effort:** ~20 minutes

### Checklist

- [x] **Implementation**
  - [x] Change line 49 in `lib/core/algorithms/maintenance_calculator.dart`:
    ```dart
    final today = now ?? DateTime.now().subtract(const Duration(days: 1));
    ```
  
- [x] **Testing**
  - [x] Add test: "excludes today from calorie aggregation"
  - [x] Run `flutter analyze` (must pass with 0 issues)
  - [x] Run `flutter test test/core/algorithms/maintenance_calculator_test.dart`
  
- [x] **Verification**
  - [x] All existing tests pass (they use explicit `now` dates)
  - [x] New test verifies today's food not included
  - [x] Maintenance estimate unchanged for existing data

### Notes

```
[x] Start: May 17, 2026
[x] Complete: May 17, 2026
[x] Verified: May 17, 2026
```
[ ] Verified: _____
```

---

## Ticket 4: Apply Calorie Clamping at OpenFoodFacts Import Time

**File:** [`tickets/004-calorie-clamping-import-time.md`](tickets/004-calorie-clamping-import-time.md)  
**Priority:** High | **Risk:** Low | **Effort:** ~45 minutes

### Checklist

- [x] **Implementation**
  - [x] Modify `FoodSearchItem.fromFoodResult()` factory to clamp calories at import
  - [x] Remove duplicate clamping from `QuickFoodLogSheet._log()` method
  - [x] Simplify save logic in `QuickFoodLogSheet` (remove redundant clamp call)
  
- [x] **Testing**
  - [x] Add test: "fromFoodResult clamps inflated calories from API"
  - [x] Add test: "fromFoodResult preserves foods with calories below macro max"
  - [x] Add test: "fromFoodResult preserves accurate calorie values"
  - [x] Optional: Widget test for QuickFoodLogSheet preview
  - [x] Run `flutter analyze` (must pass with 0 issues)
  - [x] Run `flutter test test/providers/food_search_provider_test.dart`
  
- [x] **Verification**
  - [x] OFF foods show clamped calories in search results
  - [x] QuickFoodLogSheet preview matches saved values
  - [x] Sugar alcohol foods preserved correctly
  - [x] Manual foods unaffected

### Notes

```
[x] Start: May 17, 2026
[x] Complete: May 17, 2026
[x] Verified: May 17, 2026
```

---

## Ticket 5: Improve Regression Algorithm — 14-Day Threshold + Weight Stability Detection

**File:** [`tickets/005-regression-algorithm-improvements.md`](tickets/005-regression-algorithm-improvements.md)  
**Priority:** Medium | **Risk:** Medium | **Effort:** ~90 minutes

### Checklist

- [x] **Implementation - Part A (Threshold)**
  - [x] Change line 175 in `maintenance_calculator.dart`: `if (pairedAvgCals.length < 14)`
  
- [x] **Implementation - Part B (Zero Slope)**
  - [x] Replace lines 203-210 to treat zero slope as valid maintenance
  - [x] Return `avgCalories = sx / np` as maintenance estimate
  - [x] Set `confidenceInterval = double.infinity` for zero-slope cases
  
- [x] **Testing - Update Existing Tests**
  - [x] Update test: "14 paired points at threshold produces result" (was 10)
  - [x] Update test: "no weight variance — all weights identical returns average calories" (was failure)
  - [x] Update test: "single weight entry — all 30 days use oldest weight, returns maintenance" (was failure)
  
- [x] **Testing - Add New Tests**
  - [x] Add test: "13 paired points returns insufficientPairedData failure"
  - [x] Add test: "stable weight with calorie variance returns average calories as maintenance"
  - [x] Add test: "zero slope case has infinite confidence interval"
  
- [x] **Verification**
  - [x] Run `flutter analyze` (must pass with 0 issues)
  - [x] Run `flutter test test/core/algorithms/maintenance_calculator_test.dart`
  - [x] All existing tests pass (updated for new threshold)
  - [x] New tests cover weight stability scenarios
  - [x] Manual test: Stable weight period shows maintenance estimate

### Notes

```
[x] Start: May 17, 2026
[x] Part A Complete: May 17, 2026
[x] Part B Complete: May 17, 2026
[x] Tests Updated: May 17, 2026
[x] Tests Added: May 17, 2026
[x] Verified: May 17, 2026
```

---

## Pre-Implementation Checklist

Before starting any ticket:

- [ ] Read `DISCOVERY.md` for full context
- [ ] Read the specific ticket file for detailed requirements
- [ ] Ensure you're on latest code (pull if working with team)
- [ ] Create a branch for the ticket (e.g., `ticket-001-log-default`)
- [ ] Run `flutter clean && flutter pub get` to ensure clean state

---

## Post-Implementation Checklist

After completing each ticket:

- [ ] All `flutter analyze` issues resolved
- [ ] All `flutter test` tests passing
- [ ] Manual testing completed (if applicable)
- [ ] Code reviewed (if working with team)
- [ ] Ticket file updated with completion date
- [ ] This CHECKLIST.md updated with status
- [ ] Commit with clear message (e.g., "feat: set log screen as default tab (ticket 001)")

---

## Testing Commands Reference

```bash
# Static analysis
flutter analyze > analyze.log 2>&1
# Read analyze.log after completion

# Run all tests
flutter test > test.log 2>&1
# Read test.log after completion

# Run specific test file
flutter test test/providers/macro_targets_provider_test.dart

# Run with coverage
flutter test --coverage

# Manual app testing
flutter run
```

---

## Blockers & Issues

| Date | Ticket | Blocker | Resolution |
|------|--------|---------|------------|
| - | - | None yet | - |

---

## Sign-Off

**Implementation completed by:** ________________  
**Date:** ________________  
**All tests passing:** ☐ Yes ☐ No  
**Ready for review:** ☐ Yes ☐ No  

**Reviewer:** ________________  
**Review date:** ________________  
**Approved:** ☐ Yes ☐ No  

---

## Related Files

- `issues.txt` — Original issue descriptions
- `DISCOVERY.md` — Discovery findings and analysis
- `tickets/` — Individual ticket documentation
- `lib/core/algorithms/maintenance_calculator.dart` — Regression algorithm
- `lib/providers/macro_targets_provider.dart` — Target calculations
- `lib/providers/food_search_provider.dart` — Food search and import
- `lib/app.dart` — App shell and navigation
