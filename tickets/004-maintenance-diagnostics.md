# Ticket 004: Maintenance calculator — diagnostics, threshold, and UI messages

**Issue:** #4 from issues.txt
**Size:** Large (~90 min)
**Dependencies:** None (should be done after Tickets 1-3 to avoid merge conflicts)

## Problem

The rolling regression maintenance calculator never produces a result for real-world user data. The user logged food far below maintenance for 14 days AND added daily bodyweight entries, but the algorithm returned null and fell back to Mifflin-St Jeor.

## Root Cause (Confirmed via Diagnostic Testing)

**Gate hit: Line 173 — `denom2.abs() < 1e-10`**

The second-level regression computes `weightSlope = rSlope * avgCalories + rIntercept`. The denominator `denom2 = np * sum(avgCals²) - sum(avgCals)²` equals `np² * variance(avgCals)`. When all `avgCals` values are identical (constant daily calorie intake), `denom2 = 0` and the algorithm returns null.

### Diagnostic Results

| Scenario | Result |
|----------|--------|
| 14 days constant 1200 cal + 14 days daily weight | **NULL** (denom2 = 0.0) |
| 14 days varied calories (800-1600) + 14 days daily weight | 715 cal (n=15) |
| 30 days varied food + 14 days weight (last 14 only) | 1385 cal (n=31) |
| ±10 cal variance | 1176 cal (n=15) |
| ±200 cal variance | 715 cal (n=15) |

The algorithm is mathematically correct — it *needs* calorie variance to determine the relationship between intake and weight change. But it provides **zero feedback** to the user about why it failed.

## Acceptance Criteria

- [ ] `MaintenanceResult` includes a `MaintenanceFailureReason? failureReason` field (null on success)
- [ ] Each early-return gate in `calculate()` records which reason caused the failure
- [ ] `maintenanceProvider` passes through the new result type
- [ ] `MacroTargets.compute()` handles the new result type correctly
- [ ] `MaintenanceCard` shows reason-specific messages instead of generic "insufficient data"
- [ ] Paired data threshold lowered from 14 to 10
- [ ] `_countDataDaysProvider` progress denominator updated to match (14 → 10)
- [ ] `flutter analyze` passes with zero new issues
- [ ] All existing tests pass (with updates for threshold change)
- [ ] New tests cover each failure reason

## All Early-Return Gates

| # | Line | Condition | Failure Reason |
|---|------|-----------|----------------|
| 1 | 98 | `recentWeights.length < 7` | `noWeights` |
| 2 | 126 | `xs.length < 3` | (internal, shouldn't happen — can fold into `insufficientPairedData`) |
| 3 | 138 | `denom.abs() < 1e-10` | (internal, shouldn't happen — can fold into `insufficientPairedData`) |
| 4 | 152 | `calDays < 3` | (internal, contributes to insufficient paired data) |
| 5 | 158 | `pairedAvgCals.length < 14` → `< 10` | `insufficientPairedData` |
| 6 | 173 | `denom2.abs() < 1e-10` | `noCalorieVariance` |
| 7 | 176 | `rSlope.abs() < 1e-10` | `noCorrelation` |

## Files to Change

| File | Change |
|------|--------|
| `lib/core/algorithms/maintenance_calculator.dart` | Add `MaintenanceFailureReason` enum, add `failureReason` field to `MaintenanceResult`, track reason at each early-return, lower threshold from 14 to 10 |
| `lib/providers/maintenance_provider.dart` | Pass through the new result type (no structural change needed, just type compatibility) |
| `lib/providers/macro_targets_provider.dart` | Update `compute()` to check `result.failureReason == null` for success instead of `result != null` |
| `lib/features/dashboard/widgets/maintenance_card.dart` | Update `_buildInsufficientData()` to show reason-specific messages; update progress denominator from 14 to 10 |
| `test/core/algorithms/maintenance_calculator_test.dart` | Update "insufficient data — 10 data points returns null" test; add tests for each failure reason |
| `test/providers/macro_targets_provider_test.dart` | Update tests if the provider interface changes |

## UI Messages

| Failure Reason | Message |
|----------------|---------|
| `noWeights` | "Start logging your weight to get estimates" |
| `insufficientPairedData` | "X/10 days logged" (existing progress bar, denominator updated) |
| `noCalorieVariance` | "Try logging different calorie amounts on different days" |
| `noWeightVariance` | "Your weight hasn't changed yet — keep logging" |
| `noCorrelation` | "Keep logging — need more data to find the pattern" |

Note: `noWeightVariance` and `noCorrelation` are currently both caught by gate 7 (`rSlope.abs() < 1e-10`). To distinguish them, check if all forward-filled weights are identical (→ `noWeightVariance`) vs. weights vary but don't correlate with calories (→ `noCorrelation`).

## Testing

### Updated existing tests

| Test | Change |
|------|--------|
| "insufficient data — 10 data points returns null" | Change to use 5 data points (below new threshold of 10), or update expectation |
| "no weight variance — all weights identical returns null" | Verify `failureReason == noWeightVariance` |
| "constant calories — no variance returns null" | Verify `failureReason == noCalorieVariance` |
| "no weight entries — returns null" | Verify `failureReason == noWeights` |

### New tests

| Test | Expected |
|------|----------|
| Constant calories → `noCalorieVariance` | `failureReason == noCalorieVariance` |
| Constant weight → `noWeightVariance` | `failureReason == noWeightVariance` |
| No weight entries → `noWeights` | `failureReason == noWeights` |
| 10 paired points (at threshold) → success | Non-null result, `failureReason == null` |
| 9 paired points (below threshold) → failure | Null result, `failureReason == insufficientPairedData` |
| Weight varies but no calorie correlation → `noCorrelation` | `failureReason == noCorrelation` |

## Notes

- The sealed class approach (separate `MaintenanceSuccess` / `MaintenanceFailure` types) was considered but rejected in favor of adding a nullable `failureReason` field to `MaintenanceResult`. This minimizes changes to the provider chain and UI code.
- Gates 2, 3, and 4 (lines 126, 138, 152) are internal loop-level skips that contribute to an insufficient paired count. They don't need individual failure reasons — if they prevent reaching 10 paired points, gate 5 catches it with `insufficientPairedData`.
- The `dataPoints` field in `MaintenanceResult` should still reflect the actual paired count even on failure, so the UI can show "X/10" progress.
