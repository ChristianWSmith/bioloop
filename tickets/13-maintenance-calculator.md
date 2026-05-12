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

- Synthetic data: generate 30 days of known maintenance + random noise
- Verify output is within 5% of known value
- Edge cases: empty data, < 14 days, no weight changes, constant calories

## Dependencies

T6, T7 (data sources), or both for provider wiring — algorithm can be written and unit-tested without them
