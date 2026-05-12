# T13 — Maintenance calculator algorithm

Pure Dart implementation of the rolling regression algorithm.

## Files to create

- `lib/core/algorithms/maintenance_calculator.dart` — `MaintenanceResult? calculate(...)`
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

Note: The Mifflin-St Jeor fallback estimator is implemented in a separate file
(`lib/core/algorithms/mifflin_st_jeor.dart`) as part of T10. Only the regression
algorithm lives here. This keeps the phase ordering clean — T10 (Phase 3) can use
the fallback without waiting for this ticket (Phase 4).

## Regression return type

```dart
class MaintenanceResult {
  final double maintenanceCalories;
  final double confidenceInterval;  // ±kcal (standard error of estimate)
  final int dataPoints;             // number of paired days used
}
```

## Files to modify

- `lib/providers/maintenance_provider.dart` — replace T10 stub with real implementation

## Provider

Modify `lib/providers/maintenance_provider.dart` (created as a stub in T10, replaced here):
- Watches `databaseProvider` (for table change signals) + `bodyweightProvider` (latest weight)
- Uses DAOs directly (`getEntriesForDate(d)` for each day `d` in lookback window, `getWeights`) — no separate `foodEntriesProvider` exists; the raw data is fetched inline from the DB
- Calls `MaintenanceCalculator.calculate(entries, weights)`
- Returns `AsyncValue<MaintenanceResult?>`
- Replaces the T10 stub that always returned `null`
- Note: the Mifflin-St Jeor fallback is NOT called here — this provider only wraps the regression. The fallback lives in T10's `mifflin_st_jeor.dart` utility, consumed by `macroTargetsProvider` when this provider returns null.

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

(Mifflin-St Jeor tests live in `test/core/algorithms/mifflin_st_jeor_test.dart` as part of T10. The function signature is `estimateMaintenance(sex, weightKg, heightCm, age, {int activityLevel = 3})`.)

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
- [ ] All regression unit tests pass
- [ ] **⚠ Confirm numeric stability**: when `var(cals)` is very small (near-zero), treat as null rather than dividing by zero

## Dependencies

T6, T7 (data sources), or both for provider wiring — algorithm can be written and unit-tested without them

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T13 — Maintenance calculator algorithm | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
