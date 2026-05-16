# Ticket 1: Fix Maintenance Progress Bar Count

**Priority:** High  
**Complexity:** Low  
**Estimated effort:** 15 minutes  
**Files:** `lib/features/dashboard/widgets/maintenance_card.dart`

---

## Description

The maintenance card progress bar currently shows "1/14" even when users have logged food for multiple days. This is because `_countDataDaysProvider` counts only days with both food AND weight entries (set intersection), but the maintenance algorithm forward-fills weights from the nearest logged value.

---

## Context

From `DISCOVERY.md`:

> The `_countDataDaysProvider` uses set intersection, counting only days where the user logged **both** food and weight. However, the maintenance algorithm (`lib/core/algorithms/maintenance_calculator.dart`) uses **forward-fill** for weights (lines 57-78).

**Example scenario:**
- User logs food for 10 different days
- User logs weight only on day 1
- Current progress bar: `1/14` (only day 1 has both)
- Algorithm can actually use: `10` days (food on all 10, weight forward-filled)

The progress bar should reflect the actual number of usable data points for the algorithm.

---

## Acceptance Criteria

- [ ] Progress bar counts unique days with food entries in the 30-day window
- [ ] User logging food for 10 days (regardless of weight entries) sees "10/14"
- [ ] No changes to the maintenance calculation algorithm itself
- [ ] Progress bar updates reactively when food entries are added/deleted
- [ ] Code compiles without errors

---

## Implementation

**File:** `lib/features/dashboard/widgets/maintenance_card.dart`

**Current code (lines 12-34):**
```dart
final _countDataDaysProvider = FutureProvider<int>((ref) async {
  ref.watch(dataTriggerProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 30));
  final cutoffStr =
      '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

  final foods = await db.getEntriesPaginated(limit: 365);
  final weights = await db.getWeights();

  final foodDates = foods
      .map((e) => e.loggedAt.substring(0, 10))
      .where((d) => d.compareTo(cutoffStr) >= 0)
      .toSet();

  final weightDates = weights
      .map((e) => e.loggedAt.substring(0, 10))
      .where((d) => d.compareTo(cutoffStr) >= 0)
      .toSet();

  return foodDates.intersection(weightDates).length;  // ← BUG
});
```

**Fix:** Change to count food dates only:
```dart
final _countDataDaysProvider = FutureProvider<int>((ref) async {
  ref.watch(dataTriggerProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 30));
  final cutoffStr =
      '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

  final foods = await db.getEntriesPaginated(limit: 365);

  final foodDates = foods
      .map((e) => e.loggedAt.substring(0, 10))
      .where((d) => d.compareTo(cutoffStr) >= 0)
      .toSet();

  return foodDates.length;  // Count food days only
});
```

---

## Testing Plan

### Manual Testing
1. Start with fresh app (no data)
2. Log food for 5 different days (use day navigator chevrons)
3. Log weight for today only
4. Go to Dashboard, check maintenance card
5. **Expected:** Progress bar shows "5/14"
6. **Before fix:** Would show "1/14"

### Verification
- [ ] Run `flutter analyze > analyze.log 2>&1` and read `analyze.log` — zero issues
- [ ] Run `flutter test > test.log 2>&1` and read `test.log` — all tests pass

---

## Dependencies

None — this ticket is independent.

---

## Notes

- This is a one-line fix (removing weight date collection and changing intersection to length)
- No migration or database changes needed
- No UI changes except the progress bar value
- The maintenance algorithm itself (`lib/core/algorithms/maintenance_calculator.dart`) does not need modification
