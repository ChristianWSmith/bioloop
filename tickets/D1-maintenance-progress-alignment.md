# D1: Align maintenance progress indicator with regression algorithm

**Category**: Dashboard
**Priority**: Medium
**Estimated effort**: Medium (1 file, refactor)
**Discovery**: `DISCOVERY.md` → D1

## Problem

The maintenance card shows "2/10 days logged" when the user has logged food for yesterday and today. The regression algorithm excludes today (by design, since today's data is partial), but the progress bar counts today. This misleads users into thinking they're closer to getting a maintenance estimate than they actually are.

## Root Cause

Two different date windows are used:

| Component | Window end | Includes today? |
|---|---|---|
| `_countDataDaysProvider` (progress bar) | `DateTime.now()` | Yes |
| `maintenanceProvider` (regression) | `DateTime.now() - 1 day` | No |

Additionally, the progress bar counts **distinct calendar days with food entries**, but the regression requires **paired (calories + weight-slope) data points** — these are fundamentally different metrics:

- **Distinct food days**: any day with ≥1 food entry
- **Paired data point**: a 7-day rolling window with ≥3 weight points AND ≥3 calorie days

The threshold is 10 paired data points (`maintenance_calculator.dart:175`). A user could have 10 distinct food days but still have fewer than 10 paired data points if the food logging days are clustered.

### Current code

**`maintenance_card.dart:12-28`** — `_countDataDaysProvider`:
```dart
final now = DateTime.now();                          // ← includes today
final cutoff = now.subtract(const Duration(days: 30));
// ...counts distinct food dates
```

**`maintenance_provider.dart:12`** — regression:
```dart
final now = DateTime.now().subtract(const Duration(days: 1));  // ← excludes today
```

**`maintenance_calculator.dart:175-182`** — threshold check:
```dart
if (pairedAvgCals.length < 10) {
  return MaintenanceResult(
    ...
    dataPoints: pairedAvgCals.length,  // ← already computed!
    failureReason: MaintenanceFailureReason.insufficientPairedData,
  );
}
```

## Proposed Fix

Replace `_countDataDaysProvider` with data from `maintenanceProvider`. The `MaintenanceResult` already has a `dataPoints` field counting actual paired (calories + weight-slope) windows.

### Changes to `maintenance_card.dart`

1. **Delete** `_countDataDaysProvider` (lines 12-28) — no longer needed
2. **In `_buildInsufficientData()`**: instead of watching `_countDataDaysProvider`, watch `maintenanceProvider` and use `result.dataPoints` for the progress bar
3. **Progress bar**: `min(dataPoints, 10) / 10`
4. **Update message text**: change "Log 10+ days of food + weight" to something more accurate like "Log 10+ days of food + weight data" (the existing message is close enough; the key fix is the metric alignment)

### Implementation sketch

```dart
Widget _buildInsufficientData(
  BuildContext context,
  WidgetRef ref,
  MaintenanceFailureReason? reason,
) {
  // Watch maintenanceProvider instead of _countDataDaysProvider
  final maintenanceAsync = ref.watch(maintenanceProvider);

  String message;
  bool showProgress = false;

  switch (reason) {
    case MaintenanceFailureReason.noWeights:
      message = 'Start logging your weight to get estimates';
    case MaintenanceFailureReason.insufficientPairedData:
      message = 'Log 10+ days of food + weight to calculate your maintenance';
      showProgress = true;
    case null:
      message = 'Log 10+ days of food + weight to calculate your maintenance';
      showProgress = true;
  }

  return Column(
    // ... header text unchanged ...
    if (showProgress) ...[
      const SizedBox(height: 8),
      maintenanceAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 8),
        error: (_, _) => const LinearProgressIndicator(minHeight: 8),
        data: (result) {
          final dataPoints = result?.dataPoints ?? 0;
          final progress = (dataPoints / 10.0).clamp(0.0, 1.0);
          return Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$dataPoints/10',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    ],
  );
}
```

## Acceptance Criteria

- [ ] Progress bar shows `dataPoints/10` based on actual paired data points from the regression
- [ ] Progress bar excludes today's data (aligned with regression window)
- [ ] Progress bar shows loading state when `maintenanceProvider` is still computing
- [ ] Progress bar shows 0/10 when there are no weight entries (noWeights case)
- [ ] Progress bar correctly increments as more paired data becomes available
- [ ] Progress bar caps at 10/10 even if dataPoints > 10
- [ ] `_countDataDaysProvider` is removed (no dead code)
- [ ] `flutter analyze` passes with zero issues

## Testing

### Manual testing
1. With no data → shows "Start logging your weight" message, no progress bar
2. With weights but < 10 paired food days → shows progress bar with correct count
3. Log food for today only → progress bar should NOT increment (today is excluded)
4. Log food for yesterday → progress bar should increment
5. With ≥ 10 paired data points → progress bar gone, maintenance estimate shown

### Edge cases
- User logs food for 10 consecutive days but no weights → `noWeights` message, not progress bar
- User logs weights but food days are clustered (e.g. all in last 3 days) → paired count < 10, progress reflects actual paired windows
- `maintenanceProvider` returns null result with no failure reason → progress bar shows with `dataPoints = 0`

## Files to change

| File | Lines | Change |
|---|---|---|
| `lib/features/dashboard/widgets/maintenance_card.dart` | 12-28 | Delete `_countDataDaysProvider` |
| `lib/features/dashboard/widgets/maintenance_card.dart` | 79-145 | Refactor `_buildInsufficientData()` to use `maintenanceProvider` |

## References

- `lib/providers/maintenance_provider.dart` — provides `MaintenanceResult` with `dataPoints`
- `lib/core/algorithms/maintenance_calculator.dart:175-182` — paired data point threshold
- `lib/core/algorithms/maintenance_calculator.dart:10-22` — `MaintenanceResult` class definition
