# Ticket 01 — Quick UI paper cuts

**Issues**: #14 (imperial default), #8 (delete only from history)  
**Phase**: 1  
**Dependencies**: None  
**Estimate**: ~15 minutes

---

## Context

Two trivial one-liners that fix onboarding UX and consolidate delete behavior.

### Problem 1 — Imperial default in onboarding
`_useImperial` defaults to `false` (metric) on the onboarding screen. US
users are the primary audience; imperial should be the default.

### Problem 2 — Delete button in today's entries
The `_TodayEntriesSection` in `LogFoodScreen` has a trash icon on every entry,
allowing deletion from the logging screen. The intention is that delete should
only be available from the history/log-overview screen. This button duplicates
the swipe-to-delete on the history tab and risks accidental deletion in the
quick-log flow.

---

## Acceptance Criteria

1. Onboarding screen opens with Imperial selected (lb/ft), not Metric (kg/cm).
2. Today's entries in the logging screen no longer show a delete trash icon.
3. The history screen's swipe-to-delete still works unchanged.

---

## Implementation

### Change 1 — Imperial default
**File**: `lib/features/onboarding/onboarding_screen.dart`, line 30

```diff
-  bool _useImperial = false;
+  bool _useImperial = true;
```

No other changes. The existing `_onUnitsChanged()` method handles both
directions; height/weight fields are pre-populated with imperial hints.

### Change 2 — Remove delete from today's entries
**File**: `lib/features/logging/log_food_screen.dart`, lines 512-518

Remove the trailing `IconButton` with `Icons.delete_outline` from the entry
`ListTile` in `_TodayEntriesSection`. Also remove the `_deleteEntry()` method
(lines 534-576) if it becomes dead code (confirm no other callers).

---

## Testing

### Imperial default
- Open onboarding screen
- **Verify**: The unit `SegmentedButton` has Imperial selected
- **Verify**: Height fields show ft/in inputs (two fields)
- **Verify**: Weight field hint shows "e.g. 165" (lb), suffix "lb"
- **Verify**: The unit toggle still switches to Metric correctly

### Delete removed from today's entries
- Log at least one food
- Go to the Log tab
- **Verify**: No trash icon appears on any entry row
- **Verify**: The duplicate icon (`Icons.replay`) still works
- **Verify**: The History tab's swipe-to-delete still shows confirmation dialog and removes the entry
- **Verify**: The History tab's swipe-to-delete cancel button still works

### Regression
- From the Log tab, tap an entry → QuickFoodLogSheet opens
- From the Log tab, search → select food → serving picker → meal type → Save → entry appears

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/onboarding/onboarding_screen.dart` | Line 30: default `_useImperial = true` |
| `lib/features/logging/log_food_screen.dart` | Remove delete icon + `_deleteEntry()` method |

## Open Questions

- The `_deleteEntry()` method is also referenced by `_TodayEntriesSection`
  as a callback — verify no other widget passes delete callbacks.
