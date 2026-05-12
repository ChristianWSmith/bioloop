# T13 — Maintenance calculator algorithm

Pure Dart implementation of the rolling regression algorithm.

## Files to create

- `lib/core/algorithms/maintenance_calculator.dart` — `MaintenanceResult? calculate(...)`
- `test/core/algorithms/maintenance_calculator_test.dart`

## Algorithm

See PLAN.md §5 for full detail.

```
For each day d in lookback window (default 30 days):
  cals[d]    = SUM food_entries.calories WHERE date = d
  weight[d]  = bodyweight_entries.weight_kg WHERE date = d

Smooth weight via OLS over ±3 day window → daily_weight_change[d]
Filter to days where both cals[d] and daily_weight_change[d] exist
If count < 14: return null

OLS: daily_weight_change ~ calories
  slope     = cov(cals, changes) / var(cals)
  intercept = mean(changes) - slope * mean(cals)
  maintenance = -intercept / slope
```

## Return type

```dart
class MaintenanceResult {
  final double maintenanceCalories;
  final double confidenceInterval;  // ±kcal (standard error of estimate)
  final int dataPoints;             // number of paired days used
}
```

## Provider

Create `lib/providers/maintenance_provider.dart`:
- Watches `foodEntriesProvider` + `bodyweightProvider`
- Calls `MaintenanceCalculator.calculate(entries, weights)`
- Returns `AsyncValue<MaintenanceResult?>`

## Testing

- **Unit — known maintenance**: generate 30 days where true maintenance = 2500 kcal, daily intake varies ±500, weight change = (intake − 2500) / 3500 in lbs, converted to kg. Verify computed maintenance within 5% of 2500
- **Unit — insufficient data**: 10 data points returns `null`
- **Unit — empty input**: empty lists returns `null`
- **Unit — no weight variance**: all weights identical (no change), verify returns `null` or very high confidence interval
- **Unit — constant calories**: same calories every day, variance = 0, verify returns `null` (slope cannot be computed)
- **Unit — extreme outlier**: a single outlier weight spike is smoothed by the 7-day window, maintenance stays within 10%
- **Unit — provider wiring**: insert food entries and bodyweight entries via DAO, `maintenanceProvider` emits a valid `MaintenanceResult` (integration-level)
- **Unit — confidence interval**: computed CI grows as data variance increases (proportional to standard error of estimate)

## Dependencies

T6, T7 (data sources), or both for provider wiring — algorithm can be written and unit-tested without them
