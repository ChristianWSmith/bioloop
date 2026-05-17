# BioLoop Implementation Checklist

**Created:** May 17, 2026  
**Last Updated:** May 17, 2026

---

## Ticket Status Overview

| # | Ticket | Status | Priority | Effort | Dependencies |
|---|--------|--------|----------|--------|--------------|
| 1 | Macro Bars Red Color | ⬜ Pending | High | 30 min | None |
| 2 | Calories Sparkline Widget | ⬜ Pending | Medium | 2 hrs | None |
| 3 | Calories Data Aggregation | ⬜ Pending | Medium | 1.5 hrs | None |
| 4 | Calories Graph Integration | ⬜ Pending | Medium | 45 min | T2, T3 |
| 5 | Time Range Toggle UI | ⬜ Pending | Medium | 1 hr | T4 |
| 6 | Time Range Wiring | ⬜ Pending | Medium | 1.5 hrs | T5 |
| 7 | Regression Edge Case Tests | ⬜ Pending | High | 2 hrs | None |
| 8 | Regression Long-Term Tests | ⬜ Pending | Medium | 2.5 hrs | T7 |

**Total Estimated Effort:** ~11 hours

---

## Execution Paths

### Path A: Visual Polish (Issue #1)
```
Ticket 1 (30 min)
```
**Quick win, can be done independently**

### Path B: Dashboard Enhancements (Issues #2, #3)
```
Ticket 2 (2 hrs) ──┬──> Ticket 4 (45 min) ──> Ticket 5 (1 hr) ──> Ticket 6 (1.5 hrs)
Ticket 3 (1.5 hrs) ─┘
```
**Tickets 2 and 3 can be done in parallel, then merge into 4**

### Path C: Test Coverage (Issue #4)
```
Ticket 7 (2 hrs) ──> Ticket 8 (2.5 hrs)
```
**Can be done in parallel with Paths A and B**

---

## Recommended Execution Order

1. **Ticket 1** — Quick win, builds momentum
2. **Tickets 2, 3, 7** — Can be done in parallel (no dependencies)
3. **Ticket 4** — Depends on 2+3
4. **Ticket 5** — Depends on 4
5. **Ticket 6** — Depends on 5
6. **Ticket 8** — Depends on 7

---

## Pre-Implementation Checklist

Before starting any ticket:

- [ ] Read DISCOVERY.md for context
- [ ] Read the specific ticket markdown file
- [ ] Run `flutter analyze > analyze.log 2>&1` to establish baseline
- [ ] Run `flutter test > test.log 2>&1` to ensure tests pass
- [ ] Create git branch: `git checkout -b ticket-<number>-<short-name>`

---

## Ticket 1: Macro Bars Red Color

**File:** `tickets/001-macro-bars-red-color.md`

- [ ] Read ticket requirements
- [ ] Modify `lib/features/logging/widgets/macro_bars.dart`
  - [ ] Add `isOver` parameter to `_ProgressBar`
  - [ ] Calculate `isOver` in `_MacroRow` and `_MacroColumn`
  - [ ] Use conditional color: `isOver && value > 1.0 ? Colors.red : color`
- [ ] Test manually
  - [ ] Exceed calories → bar turns red
  - [ ] Exceed protein → bar turns red
  - [ ] Exceed carbs → bar turns red
  - [ ] Exceed fat → bar turns red
  - [ ] Test in dark mode
- [ ] Run `flutter analyze > analyze.log 2>&1`
- [ ] Read `analyze.log`, verify zero issues
- [ ] Commit changes

---

## Ticket 2: Calories Sparkline Widget

**File:** `tickets/002-calories-sparkline-widget.md`

- [ ] Read ticket requirements
- [ ] Create `lib/features/dashboard/widgets/calories_sparkline.dart`
  - [ ] Mirror `BodyweightSparkline` structure
  - [ ] Accept `List<({String date, double calories})>` parameter
  - [ ] Implement line chart with `fl_chart`
  - [ ] Add touch tooltips
  - [ ] Add empty state
- [ ] Test manually
  - [ ] Empty state shows prompt
  - [ ] Single point renders
  - [ ] Multiple points render with line
  - [ ] Tooltips work
- [ ] Run `flutter analyze > analyze.log 2>&1`
- [ ] Read `analyze.log`, verify zero issues
- [ ] Commit changes

---

## Ticket 3: Calories Data Aggregation

**File:** `tickets/003-calories-data-aggregation.md`

- [ ] Read ticket requirements
- [ ] Modify `lib/core/database/database.dart`
  - [ ] Add `getCaloriesByDate()` method
  - [ ] Implement Dart-side aggregation
  - [ ] Support optional date range filtering
- [ ] Create `lib/providers/calories_provider.dart`
  - [ ] Create `caloriesByDateProvider`
  - [ ] Watch `dataTriggerProvider` and `resetTriggerProvider`
- [ ] Write unit tests
  - [ ] Test aggregation correctness
  - [ ] Test date range filtering
- [ ] Run `flutter test > test.log 2>&1`
- [ ] Read `test.log`, verify all tests pass
- [ ] Run `flutter analyze > analyze.log 2>&1`
- [ ] Read `analyze.log`, verify zero issues
- [ ] Commit changes

---

## Ticket 4: Calories Graph Integration

**File:** `tickets/004-calories-graph-integration.md`

- [ ] Read ticket requirements
- [ ] Modify `lib/features/dashboard/dashboard_screen.dart`
  - [ ] Import `CaloriesSparkline` and provider
  - [ ] Watch `caloriesByDateProvider`
  - [ ] Add calories graph below bodyweight graph
  - [ ] Handle loading/error states
- [ ] Test manually
  - [ ] Both graphs render
  - [ ] Loading states work independently
  - [ ] No overflow at 320px width
- [ ] Run `flutter analyze > analyze.log 2>&1`
- [ ] Read `analyze.log`, verify zero issues
- [ ] Commit changes

---

## Ticket 5: Time Range Toggle UI

**File:** `tickets/005-time-range-toggle.md`

- [ ] Read ticket requirements
- [ ] Create `lib/providers/dashboard_time_range_provider.dart`
  - [ ] Define `TimeRange` enum
  - [ ] Create `dashboardTimeRangeProvider`
- [ ] Modify `lib/features/dashboard/dashboard_screen.dart`
  - [ ] Add `SegmentedButton` toggle
  - [ ] Position above both graphs
  - [ ] Wire to provider
- [ ] Test manually
  - [ ] Toggle defaults to "1M"
  - [ ] Toggle switches between all 3 options
  - [ ] Resets on app restart
- [ ] Run `flutter analyze > analyze.log 2>&1`
- [ ] Read `analyze.log`, verify zero issues
- [ ] Commit changes

---

## Ticket 6: Time Range Wiring

**File:** `tickets/006-time-range-wiring.md`

- [ ] Read ticket requirements
- [ ] Modify `lib/features/dashboard/widgets/bodyweight_sparkline.dart`
  - [ ] Accept `TimeRange` parameter
  - [ ] Filter data based on range
  - [ ] Implement smart range adjustment
- [ ] Modify `lib/features/dashboard/widgets/calories_sparkline.dart`
  - [ ] Accept `TimeRange` parameter
  - [ ] Filter data based on range
  - [ ] Implement smart range adjustment
- [ ] Test manually
  - [ ] "1M" shows 30 days
  - [ ] "6M" shows 180 days
  - [ ] "All" shows all data
  - [ ] Smart adjustment works (data range < selected range)
  - [ ] Both graphs show same time window
- [ ] Run `flutter analyze > analyze.log 2>&1`
- [ ] Read `analyze.log`, verify zero issues
- [ ] Commit changes

---

## Ticket 7: Regression Edge Case Tests

**File:** `tickets/007-regression-edge-case-tests.md`

- [ ] Read ticket requirements
- [ ] Add helper functions to test file
  - [ ] `makeFood()`
  - [ ] `makeWeight()`
  - [ ] `generateFoodPattern()`
  - [ ] `generateWeightData()`
- [ ] Add 6 new tests
  - [ ] Cheat high but track accurately
  - [ ] Cheat low but track accurately
  - [ ] Inconsistent food logging
  - [ ] Barely sufficient user
  - [ ] New user with sparse data
  - [ ] Perfect adherence user
- [ ] Run `flutter test > test.log 2>&1`
- [ ] Read `test.log`, verify all 24 tests pass
- [ ] Verify tests are deterministic (run 2x, same results)
- [ ] Commit changes

---

## Ticket 8: Regression Long-Term Tests

**File:** `tickets/008-regression-longterm-tests.md`

- [ ] Read ticket requirements
- [ ] Extend helper functions for long-term data
- [ ] Add 9 new tests
  - [ ] Long-term user (6+ months)
  - [ ] Weight loss journey
  - [ ] Weight gain journey
  - [ ] Plateau then change
  - [ ] Adaptive thermogenesis
  - [ ] High variance weight measurements
  - [ ] Vacation gap
  - [ ] Reverse diet pattern
  - [ ] Multi-year user
- [ ] Run `flutter test > test.log 2>&1`
- [ ] Read `test.log`, verify all 33 tests pass
- [ ] Verify performance tests meet time limits
- [ ] Commit changes

---

## Post-Implementation Checklist

After completing all tickets:

- [ ] Run full test suite: `flutter test > test.log 2>&1`
- [ ] Run full analysis: `flutter analyze > analyze.log 2>&1`
- [ ] Read both logs, verify zero issues
- [ ] Manual QA pass on entire app
  - [ ] Dashboard renders correctly
  - [ ] Log screen renders correctly
  - [ ] Both graphs work with all time ranges
  - [ ] Macro bars turn red when exceeded
- [ ] Update this checklist with any deviations from plan
- [ ] Create PR (if applicable)

---

## Notes & Deviations

Use this section to track any changes from the original plan:

**Date:** __________  
**Ticket:** __________  
**Change:** _________________________________________________

**Date:** __________  
**Ticket:** __________  
**Change:** _________________________________________________

**Date:** __________  
**Ticket:** __________  
**Change:** _________________________________________________

---

## Quick Reference

### Commands
```bash
# Get dependencies
flutter pub get

# Analyze (lint)
flutter analyze > analyze.log 2>&1
# Then: Read analyze.log

# Run tests
flutter test > test.log 2>&1
# Then: Read test.log

# Run app
flutter run

# Generate drift code (if needed)
dart run build_runner build
```

### Important Files
- **DISCOVERY.md** — Technical discovery and findings
- **tickets/** — Individual ticket specifications
- **CHECKLIST.md** — This file

### Key Directories
- `lib/features/dashboard/` — Dashboard screens and widgets
- `lib/features/logging/` — Log screen and widgets
- `lib/core/database/` — Database layer
- `lib/providers/` — Riverpod providers
- `test/core/algorithms/` — Regression algorithm tests
