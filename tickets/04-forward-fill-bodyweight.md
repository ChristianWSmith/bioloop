# Ticket 04 — Forward-fill bodyweight for missing days

**Issues**: #13  
**Phase**: 1  
**Dependencies**: None  
**Estimate**: ~30 minutes

---

## Context

The maintenance calculator (`MaintenanceCalculator.calculate()`) uses a
sliding ±3 day window over bodyweight entries to derive rate-of-change
(slope). If a user logs weight only sporadically (e.g. Monday and Friday),
many windows have <3 weight points and are skipped. With ≥14 skipped windows
the algorithm returns null.

The fix: forward-fill bodyweight entries so every day from the lookback
cutoff to today has a weight value. If no weight is logged on a given day,
use the most recent previous logged weight.

This is a common-sense assumption: your weight didn't change just because
you forgot to log it.

---

## Acceptance Criteria

1. Every calendar day in the lookback window has a weight entry before the
   regression loop (forward-filled from the last actual measurement).
2. The minimum 7-weight-entry threshold still applies (must have at least 7
   real logged weights).
3. The algorithm returns a result when there are ≥14 valid paired data points
   after forward-filling, even with sparse logging (e.g. Mon+Fri only).
4. Existing behavior for daily logging is unchanged.
5. Results (maintenance calories, confidence interval) are still reasonable
   (~5-10% of true maintenance).

---

## Implementation

**File**: `lib/core/algorithms/maintenance_calculator.dart`

After line 48 (`recentWeights` built) and before line 50 (check
`recentWeights.length < 7`), add:

```dart
// Forward-fill: ensure every day has a weight entry
final filledWeights = <BodyweightEntry>[];
final dateMap = <String, double>{};
for (final w in recentWeights) {
  final date = w.loggedAt.substring(0, 10);
  dateMap[date] = w.weightKg;
}

final start = DateTime.parse(cutoffStr);
final end = today;
double? lastKnownWeight;
for (int d = 0; d <= end.difference(start).inDays; d++) {
  final date = start.add(Duration(days: d));
  final dateStr =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  if (dateMap.containsKey(dateStr)) {
    lastKnownWeight = dateMap[dateStr]!;
  }
  if (lastKnownWeight != null) {
    filledWeights.add(BodyweightEntry(
      id: -1,
      weightKg: lastKnownWeight,
      loggedAt: dateStr,
    ));
  }
}

// Replace recentWeights with filledWeights
recentWeights = filledWeights;
recentDates = filledWeights.map((e) => e.loggedAt.substring(0, 10)).toList();
```

The weight threshold check (`recentWeights.length < 7`) still operates on
`filledWeights` — actual logged entries guarantee ≥7 real measurements since
`filledWeights` is a superset of `recentWeights`.

---

## Testing

### Unit tests (`test/core/algorithms/maintenance_calculator_test.dart`)

- **Add test**: "sparse logging — weights Mon+Fri only, still produces result"
  - 4 weeks of Mon+Fri weight entries (8 total) + daily calories
  - Verify result is not null
  - Verify maintenance calories within 5%
  - Verify dataPoints ≥ 14

- **Modify existing test**: "insufficient data — 10 data points returns null"
  - Ensure this still returns null (10 weights across 10 days should still
    fail the ≥14 paired points check)

- **Add test**: "single gap — one missing day doesn't break result"
  - 30 days of data, one day without a weight
  - Verify result is not null

### Manual tests
- Log bodyweight Mon+Fri for 3 weeks, log food daily
- Go to Dashboard
- **Verify**: Maintenance estimate is shown (not "Insufficient data")
- Stop logging weight for a week
- **Verify**: Maintenance still shows (using last known weight)

---

## Files Changed

| File | Change |
|------|--------|
| `lib/core/algorithms/maintenance_calculator.dart` | Add forward-fill loop after weight collection |
| `test/core/algorithms/maintenance_calculator_test.dart` | Add sparse-logging + gap tests |

---

## Open Questions

- Should forward-filled weights be visually flagged somewhere (e.g. sparkline
  markers)? Probably not — this is an internal calculation detail.
- The `BodyweightEntry` constructor with `id: -1` is fine since the
  calculator only uses `.weightKg` and `.loggedAt`. No DB writes.
