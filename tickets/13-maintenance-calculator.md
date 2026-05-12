# T13 — Maintenance calculator algorithm

Pure Dart implementation of the rolling regression algorithm and the Mifflin-St Jeor fallback estimator.

## Files to create

- `lib/core/algorithms/maintenance_calculator.dart` — `MaintenanceResult? calculate(...)` + `double estimateMaintenance(...)`
- `test/core/algorithms/maintenance_calculator_test.dart`

## Algorithm — regression

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

## Algorithm — fallback estimate (Mifflin-St Jeor)

Used by T10 when regression returns null and onboarding is complete:

```dart
double estimateMaintenance({
  required String sex,
  required double weightKg,
  required double heightCm,
  required int age,
}) {
  double bmr;
  if (sex == 'male') {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
  } else {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  }
  return bmr * 1.55; // moderate activity
}
```

This is a pure, stateless function — no DB or provider dependency.

## Regression return type

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
- Note: the Mifflin-St Jeor fallback is NOT called here — this provider only wraps the regression. The fallback lives in T10's `macroTargetsProvider` which calls `estimateMaintenance()` directly when this provider returns null.

## Testing

### Regression tests

- **Unit — known maintenance**: generate 30 days where true maintenance = 2500 kcal, daily intake varies ±500, weight change = (intake − 2500) / 3500 in lbs, converted to kg. Verify computed maintenance within 5% of 2500
- **Unit — insufficient data**: 10 data points returns `null`
- **Unit — empty input**: empty lists returns `null`
- **Unit — no weight variance**: all weights identical (no change), verify returns `null` or very high confidence interval
- **Unit — constant calories**: same calories every day, variance = 0, verify returns `null` (slope cannot be computed)
- **Unit — extreme outlier**: a single outlier weight spike is smoothed by the 7-day window, maintenance stays within 10%
- **Unit — provider wiring**: insert food entries and bodyweight entries via DAO, `maintenanceProvider` emits a valid `MaintenanceResult` (integration-level)
- **Unit — confidence interval**: computed CI grows as data variance increases (proportional to standard error of estimate)

### Mifflin-St Jeor tests

- **Unit — male**: sex=male, weight=80kg, height=178cm, age=30 → BMR = 10×80 + 6.25×178 − 5×30 + 5 = 1757.5, ×1.55 = 2724.1. Verify within 0.1%
- **Unit — female**: sex=female, same inputs → BMR = 10×80 + 6.25×178 − 5×30 − 161 = 1591.5, ×1.55 = 2466.8. Verify within 0.1%
- **Unit — weight changes**: weight=70kg (same sex/height/age) produces lower result than 80kg
- **Unit — height changes**: height=160cm produces lower result than 178cm

## Human verification

### Regression
- [ ] `flutter analyze` passes with zero errors
- [ ] Synthetic data test: 30 days with true maintenance = 2500 kcal returns result within 5% — run test, inspect the output
- [ ] Edge case: 13 data points returns `null` (below threshold of 14)
- [ ] Edge case: all weights identical returns `null` (no trend to regress)
- [ ] Edge case: all calories identical returns `null` (no variance, slope undefined)
- [ ] Confidence interval widens as data variance increases — inspect the math
- [ ] Provider recomputes on new food or weight insert (not on every build)
- [ ] Provider caches result — if no new data, calling `.future` twice returns the same result without recomputation
- [ ] All regression + Mifflin-St Jeor unit tests pass
- [ ] **⚠ Confirm numeric stability**: when `var(cals)` is very small (near-zero), treat as null rather than dividing by zero

### Mifflin-St Jeor
- [ ] Male: 80kg, 178cm, 30y → ~2724 kcal — verify output matches hand calculation
- [ ] Female: 80kg, 178cm, 30y → ~2467 kcal — verify output matches hand calculation
- [ ] Changing weight/height/age produces proportional changes
- [ ] Function is pure — no DB, no provider, no side effects

## Dependencies

T6, T7 (data sources), or both for provider wiring — algorithm can be written and unit-tested without them

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T13 — Maintenance calculator algorithm | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
