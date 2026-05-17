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
| [002](#ticket-2-clamp-calorie-targets-to-non-negative-values) | Clamp calorie targets | High | ⬜ Pending | 0% |
| [003](#ticket-3-exclude-current-day-from-regression-calculation) | Exclude current day | Medium | ⬜ Pending | 0% |
| [004](#ticket-4-apply-calorie-clamping-at-openfoodfacts-import-time) | Calorie clamping timing | High | ⬜ Pending | 0% |
| [005](#ticket-5-improve-regression-algorithm--14-day-threshold--weight-stability-detection) | Regression improvements | Medium | ⬜ Pending | 0% |

**Overall Progress:** 1/5 tickets complete (20%)

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

- [ ] **Implementation**
  - [ ] Add `targetCalories = max(0.0, targetCalories);` in `MacroTargets.compute()` after line 50
  - [ ] Verify `dart:math` import exists (should already be there)
  
- [ ] **Testing**
  - [ ] Add test: "target calories clamped to 0 when deficit exceeds regression maintenance"
  - [ ] Add test: "target calories clamped to 0 when Mifflin-St Jeor estimate is very low"
  - [ ] Add test: "normal deficit produces correct positive target (not clamped)"
  - [ ] Run `flutter analyze` (must pass with 0 issues)
  - [ ] Run `flutter test test/providers/macro_targets_provider_test.dart`
  
- [ ] **Verification**
  - [ ] All existing tests pass
  - [ ] New tests verify boundary conditions
  - [ ] Target calories never negative in manual testing

### Notes

```
[ ] Start: _____
[ ] Complete: _____
[ ] Verified: _____
```

---

## Ticket 3: Exclude Current Day from Regression Calculation

**File:** [`tickets/003-exclude-current-day-regression.md`](tickets/003-exclude-current-day-regression.md)  
**Priority:** Medium | **Risk:** Low | **Effort:** ~20 minutes

### Checklist

- [ ] **Implementation**
  - [ ] Change line 49 in `lib/core/algorithms/maintenance_calculator.dart`:
    ```dart
    final today = (now ?? DateTime.now()).subtract(const Duration(days: 1));
    ```
  
- [ ] **Testing**
  - [ ] Add test: "excludes today from calorie aggregation"
  - [ ] Run `flutter analyze` (must pass with 0 issues)
  - [ ] Run `flutter test test/core/algorithms/maintenance_calculator_test.dart`
  
- [ ] **Verification**
  - [ ] All existing tests pass (they use explicit `now` dates)
  - [ ] New test verifies today's food not included
  - [ ] Maintenance estimate unchanged for existing data

### Notes

```
[ ] Start: _____
[ ] Complete: _____
[ ] Verified: _____
```

---

## Ticket 4: Apply Calorie Clamping at OpenFoodFacts Import Time

**File:** [`tickets/004-calorie-clamping-import-time.md`](tickets/004-calorie-clamping-import-time.md)  
**Priority:** High | **Risk:** Low | **Effort:** ~45 minutes

### Checklist

- [ ] **Implementation**
  - [ ] Modify `FoodSearchItem.fromFoodResult()` factory to clamp calories at import
  - [ ] Remove duplicate clamping from `QuickFoodLogSheet._log()` method
  - [ ] Simplify save logic in `QuickFoodLogSheet` (remove redundant clamp call)
  
- [ ] **Testing**
  - [ ] Add test: "fromFoodResult clamps inflated calories from API"
  - [ ] Add test: "fromFoodResult preserves foods with calories below macro max"
  - [ ] Add test: "fromFoodResult preserves accurate calorie values"
  - [ ] Optional: Widget test for QuickFoodLogSheet preview
  - [ ] Run `flutter analyze` (must pass with 0 issues)
  - [ ] Run `flutter test test/providers/food_search_provider_test.dart`
  
- [ ] **Verification**
  - [ ] OFF foods show clamped calories in search results
  - [ ] QuickFoodLogSheet preview matches saved values
  - [ ] Sugar alcohol foods preserved correctly
  - [ ] Manual foods unaffected

### Notes

```
[ ] Start: _____
[ ] Complete: _____
[ ] Verified: _____
```

---

## Ticket 5: Improve Regression Algorithm — 14-Day Threshold + Weight Stability Detection

**File:** [`tickets/005-regression-algorithm-improvements.md`](tickets/005-regression-algorithm-improvements.md)  
**Priority:** Medium | **Risk:** Medium | **Effort:** ~90 minutes

### Checklist

- [ ] **Implementation - Part A (Threshold)**
  - [ ] Change line 175 in `maintenance_calculator.dart`: `if (pairedAvgCals.length < 14)`
  
- [ ] **Implementation - Part B (Zero Slope)**
  - [ ] Replace lines 203-210 to treat zero slope as valid maintenance
  - [ ] Return `avgCalories = sx / np` as maintenance estimate
  - [ ] Set `confidenceInterval = double.infinity` for zero-slope cases
  
- [ ] **Testing - Update Existing Tests**
  - [ ] Update test: "14 paired points at threshold produces result" (was 10)
  - [ ] Update test: "no weight variance — all weights identical returns average calories" (was failure)
  - [ ] Update test: "single weight entry — all 30 days use oldest weight, returns maintenance" (was failure)
  
- [ ] **Testing - Add New Tests**
  - [ ] Add test: "13 paired points returns insufficientPairedData failure"
  - [ ] Add test: "stable weight with calorie variance returns average calories as maintenance"
  - [ ] Add test: "zero slope case has infinite confidence interval"
  
- [ ] **Verification**
  - [ ] Run `flutter analyze` (must pass with 0 issues)
  - [ ] Run `flutter test test/core/algorithms/maintenance_calculator_test.dart`
  - [ ] All existing tests pass (updated for new threshold)
  - [ ] New tests cover weight stability scenarios
  - [ ] Manual test: Stable weight period shows maintenance estimate

### Notes

```
[ ] Start: _____
[ ] Part A Complete: _____
[ ] Part B Complete: _____
[ ] Tests Updated: _____
[ ] Tests Added: _____
[ ] Verified: _____
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
