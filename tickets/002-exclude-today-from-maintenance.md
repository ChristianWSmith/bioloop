# 002 — Exclude today from maintenance regression inputs

**Issues**: #3
**Files**:
- `lib/providers/maintenance_provider.dart` (fix)
- `test/core/algorithms/maintenance_calculator_test.dart` (verify no regression)

**Effort**: Small (1-2 lines)

---

## Context

The maintenance calculator uses a rolling 30-day lookback window ending at `now`. When `now` is the current moment, today's partial food entries (only breakfast/lunch logged so far) get included in the regression, which biases the estimate downward.

Current code in `maintenance_provider.dart` lines 12-13:
```dart
final now = DateTime.now();
final lookback = 30;
```

This is passed to `MaintenanceCalculator.calculate()` which uses it at line 24:
```dart
final today = now ?? DateTime.now();
```

The algorithm then forward-fills weights and pairs them with calorie averages for every day in the window, including today. If today's food log is incomplete, the paired data point for today shows artificially low calories, dragging down the estimated maintenance.

---

## Acceptance criteria

1. Today's food entries and weight are excluded from the regression calculation
2. The lookback window still spans 30 days (ending yesterday instead of today)
3. All existing tests in `maintenance_calculator_test.dart` pass
4. No other behavior is affected — the algorithm, result type, and provider remain the same

---

## Implementation notes

In `lib/providers/maintenance_provider.dart`, change line 13:
```dart
// Before:
final now = DateTime.now();
// After:
final now = DateTime.now().subtract(const Duration(days: 1));
```

This shifts the entire 30-day window to end at 23:59:59 yesterday, excluding today's incomplete data.

---

## Testing

1. Run `flutter test` and verify all maintenance calculator tests pass
2. Specifically verify the `maintenanceProvider` integration test (the DAO-based test that inserts 60 days of data) still returns a valid result within 5% of the known maintenance value
3. Run `flutter analyze` — zero issues
