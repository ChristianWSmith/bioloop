# BioLoop Discovery Document

**Date:** May 17, 2026  
**Purpose:** Technical discovery for implementing 4 pending issues related to macro bars, historical graphs, time range toggle, and regression algorithm tests.

---

## Issue 1: Macro/Calorie Bars Should Turn Red When Exceeded

### Current State

**File:** `lib/features/logging/widgets/macro_bars.dart`

The `MacroBars` widget displays 4 progress bars (calories, protein, carbs, fat) at the top of the log screen. Currently:
- Bars use static colors defined at call site (calories=primary, protein=blue, carbs=green, fat=orange)
- `_ProgressBar` widget clamps visual fill to 100% but does NOT change color when exceeded
- No `isOver` logic exists (unlike `MacroRing`)

**Comparison with MacroRing:**
- `MacroRing` (dashboard) already implements `isOver` detection at line 27: `final isOver = target > 0 && consumed > target;`
- Ring painter changes to `Colors.red` when `isOver` is true (line 138)
- Shows "XXX over" text when exceeded (lines 88-98)

### Implementation Findings

**Required changes to `MacroBars`:**
1. Add `isOver` calculation for each macro (4 total):
   ```dart
   final isOverCalories = targets.targetCalories > 0 && consumedCalories > targets.targetCalories;
   final isOverProtein = targets.proteinGrams > 0 && consumedProtein > targets.proteinGrams;
   final isOverCarbs = targets.carbsGrams > 0 && consumedCarbs > targets.carbsGrams;
   final isOverFat = targets.fatGrams > 0 && consumedFat > targets.fatGrams;
   ```

2. Pass `isOver` flag to `_ProgressBar` widget (currently only accepts `value` and `color`)

3. Modify `_ProgressBar.build()` to use red when `isOver && value > 1.0`

**Call site:** `lib/features/logging/combined_log_screen.dart:326-332`
- MacroBars is instantiated with `targets` and consumed totals
- All required data is already available

**Complexity:** Low (15-20 line changes)
**Risk:** Minimal (purely visual, no data flow changes)

---

## Issue 2: Add Historical Calories Consumed Graph Below Bodyweight Graph

### Current State

**Dashboard layout:** `lib/features/dashboard/dashboard_screen.dart`
- Bodyweight graph at lines 136-146: `BodyweightSparkline(entries: weights)`
- No calories graph exists

**BodyweightSparkline implementation:** `lib/features/dashboard/widgets/bodyweight_sparkline.dart`
- Uses `fl_chart` package with `LineChart` widget
- Shows last 30 days by default (line 30: `thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30))`)
- Supports touch tooltips with date + weight value
- Computes trend line via `computeBodyweightTrend()` helper (lines 192-244)
- Accepts `List<BodyweightEntry>` and converts to `FlSpot` with day numbers

**Data fetching:**
- `bodyweightProvider` fetches all weights (no limit)
- `maintenanceProvider` fetches 365 days of food entries (line 19: `limit: 365`)
- No provider currently aggregates calories by date for historical display

### Implementation Findings

**Option A: Create new `CaloriesSparkline` widget**
- Duplicate `BodyweightSparkline` structure
- Accept `List<({String date, double calories})>` instead of `BodyweightEntry`
- Use same visual style (blue line, dots, trend line, tooltips)

**Option B: Generalize `BodyweightSparkline` to accept custom data**
- Create generic `TimeSeriesSparkline<T>` widget
- Pass data transformer function
- More complex but more reusable

**Recommended: Option A** (simpler, clearer separation of concerns)

**Data aggregation requirement:**
Need to add method to `AppDatabase` or create new provider:
```dart
Future<List<({String date, double calories})>> getCaloriesByDate({
  DateTime? startDate,
  DateTime? endDate,
}) async {
  // Group food_entries by date, sum calories
  // Return sorted list
}
```

**Current DB capabilities:**
- `getEntriesPaginated()` returns raw entries (lines 243-252 in database.dart)
- `getEntriesForDate()` returns entries for single date (lines 154-163)
- No bulk aggregation method exists — would need to aggregate in Dart

**Dashboard integration:**
- Add new widget below `BodyweightSparkline` in `dashboard_screen.dart`
- Fetch data via new provider watching same triggers (`dataTriggerProvider`, `resetTriggerProvider`)
- Use same 30-day window initially

**Complexity:** Medium (new widget + data aggregation logic)
**Risk:** Low (additive feature, no existing code modified)

---

## Issue 3: Time Range Toggle (1 Month / 6 Months / All Time)

### Current State

**No time range selection exists.** Both graphs use hardcoded windows:
- Bodyweight: 30 days (line 30 of `bodyweight_sparkline.dart`)
- Calories: Would default to 30 days per Issue 2 implementation

**State management:**
- Dashboard uses Riverpod providers throughout
- No existing UI state for time range preferences
- `user_goals` table has 13 columns but no UI preference fields

### Implementation Findings

**TimeRange enum:**
```dart
enum TimeRange { oneMonth, sixMonths, allTime }
```

**Provider structure:**
```dart
final dashboardTimeRangeProvider = StateProvider<TimeRange>((ref) => TimeRange.oneMonth);
```

**UI component:**
- Use `SegmentedButton<TimeRange>` (Material 3, matches app style)
- Place above both graphs in `dashboard_screen.dart`
- Three options: "1M", "6M", "All"

**Date calculation helper:**
```dart
DateTime _calculateStartDate(TimeRange range) {
  final now = DateTime.now();
  return switch (range) {
    TimeRange.oneMonth => now.subtract(const Duration(days: 30)),
    TimeRange.sixMonths => now.subtract(const Duration(days: 180)),
    TimeRange.allTime => DateTime(2000, 1, 1), // Effectively all time
  };
}
```

**Data fetching changes:**

For `BodyweightSparkline`:
- Currently filters in-widget (line 31-35)
- Would need to accept `startDate` parameter OR use provider that filters

For calories graph:
- Would need similar filtering logic

**Smart range adjustment requirement:**
> "if the time range requested is greater than the difference between the first and last data point, the time displayed should be reduced to the range from the first to the last"

Implementation:
```dart
DateTime effectiveStartDate = calculatedStartDate;
if (firstDataPoint != null && firstDataPoint.date.isAfter(calculatedStartDate)) {
  effectiveStartDate = firstDataPoint.date;
}
```

Both graphs must use identical `minX`/`maxX` or date range.

**Provider invalidation:**
- Time range changes should NOT trigger data refresh (data is static)
- Only UI rebuild needed
- Can pass range as widget parameter, no need for provider watch

**Persistence decision:**
Per user feedback: **NOT persistent**, defaults to 1 month on each launch.

**Complexity:** Medium (new state + UI + coordinate both graphs)
**Risk:** Low (additive, no breaking changes)

---

## Issue 4: Comprehensive Unit Tests for Regression Algorithm

### Current Test Coverage

**File:** `test/core/algorithms/maintenance_calculator_test.dart` (679 lines)

**Existing tests (18 total):**
1. ✅ Known maintenance = 2500 kcal (60 days, pattern variance)
2. ✅ Insufficient data — 5 data points returns `insufficientPairedData`
3. ✅ 14 paired points at threshold produces result
4. ✅ Empty input returns `noWeights`
5. ✅ No weight variance — returns average calories with infinite CI
6. ✅ Constant calories — returns average calories with infinite CI
7. ✅ Extreme outlier — spike smoothed, within 10%
8. ✅ Confidence interval grows with variance
9. ✅ Sparse logging — Mon+Fri only, still produces result
10. ✅ Single gap — one missing day doesn't break
11. ✅ Single weight entry — forward-fill works, returns maintenance
12. ✅ Delete oldest weight — assumption shifts to new oldest
13. ✅ Weight entries start mid-window — prior dates use oldest weight
14. ✅ No weight entries — returns `noWeights`
15. ✅ Excludes today from calorie aggregation
16. ⚠️ 13 paired points test (actually verifies 14+ due to implementation)
17. ✅ Stable weight with calorie variance (duplicate of #5)
18. ✅ Zero slope case has infinite CI (duplicate of #5)

### Coverage Gaps Identified

Per issue requirements: "exhaustive" testing for real-world usage patterns.

**Missing scenarios:**

1. **Cheat high but track accurately**
   - Weekend binge pattern: 500-1000 cal over maintenance on Sat/Sun
   - Perfect logging fidelity
   - Verify algorithm still converges despite large variance

2. **Cheat low but track accurately**
   - Weekday restriction: 500 cal under, weekend compensation
   - Tests algorithm handles intentional variance

3. **Inconsistent food logging**
   - Logs food 4-5 days/week (not daily)
   - Tests paired data calculation with missing calorie days

4. **Long-term user (6+ months)**
   - 180-365 days of data
   - Verify algorithm stability, performance
   - Test no degradation with large datasets

5. **Barely sufficient user (exactly 10 paired days)**
   - Edge case at minimum threshold
   - Verify doesn't fail with 9 points, succeeds with 10

6. **Weight loss journey**
   - Consistent 1-2 lb/week loss over 90 days
   - Verify maintenance estimate reflects changing baseline

7. **Weight gain journey**
   - Consistent gain over 90 days
   - Mirror of #6

8. **Plateau then change**
   - 30 days stable weight, then 30 days deficit
   - Tests algorithm responsiveness to regime change

9. **Adaptive thermogenesis simulation**
   - Maintenance shifts over 180 days (body adapts)
   - Tests if rolling window captures changing maintenance

10. **New user with sparse data (10-14 days)**
    - Just enough data to pass threshold
    - Verify confidence interval is appropriately wide

11. **Perfect adherence user**
    - Eats exact same calories daily
    - Weight stable (no variance)
    - Should return average calories with infinite CI

12. **High variance weight measurements**
    - Scale noise: ±2 lb daily fluctuations
    - Tests trend smoothing effectiveness

13. **Vacation gap**
    - No logging for 7-14 days mid-stream
    - Tests gap handling beyond single-day gaps

14. **Reverse diet pattern**
    - Gradual calorie increase over 90 days
    - Weight stable (activity increases)
    - Tests algorithm with trending calories but stable weight

15. **Multi-year user**
    - 2+ years of data
    - Performance test + algorithm stability

### Test Structure Template

Each new test should verify:
```dart
test('scenario name', () {
  final result = MaintenanceCalculator.calculate(
    foodEntries: [...],
    weightEntries: [...],
    now: DateTime(...),
  );

  expect(result, isNotNull);
  expect(result!.failureReason, isNull); // or specific reason
  expect(result.maintenanceCalories, closeTo(expected, tolerance));
  expect(result.confidenceInterval, withinExpectedRange);
  expect(result.dataPoints, greaterThanOrEqualTo(minimum));
});
```

### Test Data Generation Strategy

**Helper functions to add:**
```dart
FoodEntry makeFood({required double calories, required DateTime date, ...});
BodyweightEntry makeWeight({required double weightKg, required DateTime date});
List<FoodEntry> generateFoodPattern({
  required double baseCalories,
  required List<double> weeklyPattern,
  required int days,
});
List<BodyweightEntry> generateWeightLoss({
  required double startWeight,
  required double weeklyLbs,
  required int days,
  double noise = 0.1,
});
```

**Complexity:** Medium-High (15 new tests, ~500-800 lines)
**Risk:** None (tests only, no production code changes)

---

## Cross-Cutting Concerns

### State Management Patterns

**Trigger providers:**
- `dataTriggerProvider`: Incremented on any data mutation (food, weight)
- `resetTriggerProvider`: Incremented on full data reset
- Both are `StateProvider<int>` (simple counter)
- Providers watch these to invalidate caches

**Pattern for new providers:**
```dart
final caloriesByDateProvider = FutureProvider<List<CalorieDay>>((ref) async {
  ref.watch(resetTriggerProvider);
  ref.watch(dataTriggerProvider);
  final db = ref.watch(databaseProvider);
  // fetch and aggregate
});
```

### fl_chart Integration

**Current usage:**
- `LineChart` with `LineChartData`
- `FlSpot(x: dayNumber, y: value)`
- Custom `LineChartBarData` for raw line + trend line
- Touch tooltips via `LineTouchTooltipData`

**Key considerations:**
- All spots must have sequential x-values for proper rendering
- `minX`/`maxX` control visible range
- `minY`/`maxY` auto-calculated with padding (lines 61-68 of `bodyweight_sparkline.dart`)

### Database Performance Notes

**Current limits:**
- `maintenanceProvider` fetches 365 days of food (line 19)
- No pagination for historical queries
- All weights fetched without limit

**For "all time" range:**
- May need to add date range parameters to DB queries
- Consider adding index on `loggedAt` if not exists (drift auto-indexes primary keys only)

---

## File Change Summary

| Issue | Files to Create | Files to Modify | Lines Changed (est.) |
|-------|----------------|-----------------|---------------------|
| 1 | 0 | 1 (`macro_bars.dart`) | 20 |
| 2 | 1 (`calories_sparkline.dart`) | 2 (`dashboard_screen.dart`, new provider) | 150 |
| 3 | 0 | 3 (`dashboard_screen.dart`, sparkline widgets) | 80 |
| 4 | 0 | 1 (`maintenance_calculator_test.dart`) | 600 |

**Total:** 1 new file, 7 modified files, ~850 lines

---

## Dependencies & Packages

**Currently used:**
- `fl_chart`: Already in pubspec (line 1 of `bodyweight_sparkline.dart`)
- `flutter_riverpod`: State management
- `drift`: Database
- `intl`: Date formatting

**No new dependencies required** for any of the 4 issues.

---

## Testing Strategy

### Widget Tests Needed

**Issue 1:**
- `test/features/logging/widgets/macro_bars_test.dart` (new file)
  - Test bars turn red when exceeded
  - Test all 4 macros independently

**Issue 2:**
- `test/features/dashboard/widgets/calories_sparkline_test.dart` (new file)
  - Empty state
  - Single data point
  - Multiple points
  - Touch interaction

**Issue 3:**
- Extend `dashboard_screen_test.dart`
  - Toggle switches time range
  - Both graphs update together
  - Smart range adjustment works

### Integration Tests

**Issue 4:**
- All in `test/core/algorithms/maintenance_calculator_test.dart`
- Can run independently (no widget tests)

---

## Potential Gotchas

### Issue 1
- Ensure color change is visible in both light/dark themes
- Test with target = 0 (edge case, shouldn't happen but defensive)

### Issue 2
- Calories graph Y-axis scale: auto-adjust like bodyweight or fixed?
  - **Decision:** Auto-adjust like bodyweight (mirrors existing behavior)
- Tooltip format: "Jan 15: 2,345 cal" vs "1/15: 2,345 cal"
  - **Decision:** Match bodyweight format (`DateFormat('M/d/yy')`)

### Issue 3
- Both graphs must sync to same time range even if one has less data
  - Example: 6 months selected, but only 3 months of weight data
  - **Result:** Both show 6 months (calories graph shows full range, weight graph shows 3 months of data in 6-month window)
- "All time" with 2+ years of data: performance test recommended

### Issue 4
- Some scenarios may be impossible to distinguish (e.g., "cheat high" vs "high variance")
- Focus on algorithm correctness, not user behavior labeling
- Tests should be deterministic (use fixed Random seeds)

---

## Recommendations

### Priority Order (if implementing)
1. **Issue 1** — Quickest win, visual polish, zero risk
2. **Issue 4** — Independent, can run in parallel, improves confidence
3. **Issue 2** — Foundation for Issue 3
4. **Issue 3** — Depends on Issue 2, most complex

### Code Review Checklist

**Issue 1:**
- [ ] All 4 bars turn red independently
- [ ] Color matches `MacroRing` red (`Colors.red`)
- [ ] No console errors in debug mode

**Issue 2:**
- [ ] Graph renders with 0, 1, and many data points
- [ ] Tooltips show correct date + calorie format
- [ ] Matches bodyweight visual style
- [ ] Dashboard doesn't overflow on small screens

**Issue 3:**
- [ ] Toggle switches between all 3 options
- [ ] Both graphs update simultaneously
- [ ] Smart range adjustment works (data range < selected range)
- [ ] Defaults to 1 month on fresh launch

**Issue 4:**
- [ ] All 15 new tests pass
- [ ] No flaky tests (deterministic with seeds)
- [ ] Test names clearly describe scenario
- [ ] Existing tests still pass

---

## Open Questions (Resolved)

| Question | Decision |
|----------|----------|
| Should time range persist? | No, defaults to 1 month each launch |
| Should "all time" have a cap? | No, show all available data |
| What visual style for calories graph? | Same as bodyweight (blue line, dots, trend) |
| Which issue to prioritize? | No priority needed, all will be addressed |

---

**End of Discovery Document**
