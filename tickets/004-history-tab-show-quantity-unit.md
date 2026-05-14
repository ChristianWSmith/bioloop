# T4: Show quantity/unit on history tab entries

**Issue:** #3
**Effort:** ~5 min
**Dependencies:** None

## Context

In `HistoryScreen` (`lib/features/history/history_screen.dart`), each food entry is rendered as a `ListTile` (lines 298-306). The subtitle currently shows:

```
370 cal  •  P20g  C45g  F8g  •  14:30
```

The `FoodEntry` model has `servings` (double) and `servingLabel` (String, pre-formatted like `"100 g"` or `"2 servings"`) available, but neither is displayed. Users have no way to see how much of a food was logged from the history list — they must tap the entry and open the edit sheet to find out.

The `edit_entry_sheet.dart` already uses `widget.entry.servingLabel` as the quantity field label hint, confirming this data is correct and useful.

## Intent

Add the logged quantity/unit to each history entry's subtitle so users can see portion sizes at a glance without drilling into the edit sheet.

## Changes

**File:** `lib/features/history/history_screen.dart`

Modify the subtitle text at line 300-302 to include `entry.servingLabel`. Example format:

```
370 cal  •  100 g  •  P20g  C45g  F8g  •  14:30
```

The `servingLabel` field already contains the formatted quantity + unit (e.g. `"100 g"`, `"2.5 servings"`), so no additional formatting is needed.

## Testing

- **Manual:** Log some foods with various quantities (100g, 2 servings, 1.5 cups, etc.). Open the History tab. Verify each entry shows the quantity/unit in its subtitle.
- **Widget test:** Insert `FoodEntry` records with known `servingLabel` values into an in-memory DB. Render `HistoryScreen` in a `ProviderScope`. Verify the subtitle `Text` widget contains the expected serving label string.
