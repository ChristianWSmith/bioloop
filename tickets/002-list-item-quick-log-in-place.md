# TICKET-002: Tapping a "My Foods" list item opens quick-log sheet without closing search

**Priority:** Medium (usability — inconsistent behavior)
**File:** `lib/features/logging/widgets/food_search_delegate.dart`
**Dependency:** Best done after TICKET-001 (same file, avoids merge conflicts)
**Estimate:** ~30min

---

## Context

In the "My Foods" search results, there are two ways to interact with a food item:

1. **Tap the list item** — calls `onSelectItem(item)`, which triggers `close(context, item)`, exits the search, and returns the item. Then `CombinedLogScreen._onSearch()` opens the quick-log sheet.
2. **Tap the `Icons.add_circle_outline` trailing button** — calls `onQuickLog!(item)`, which opens the quick-log sheet in-place (search stays open underneath), and only pops the search delegate after the sheet is dismissed.

The user prefers behavior #2 (sheet opens in-place, search stays underneath, returns to log only after save/cancel). They want tapping the list item to behave the same way, and the redundant button to be removed.

### Why the recipe form is NOT affected

`RecipeFormScreen._addIngredient()` does NOT pass `onQuickLog` to `FoodSearchDelegate`. When `onQuickLog` is null, the trailing icon button is not rendered (line 218: `trailing: onQuickLog != null ? ... : null`). The recipe form relies on `onSelectItem` to return the selected food for its own quantity dialog. **These paths must remain unchanged.**

---

## Acceptance criteria

1. **Tapping a food list item** when `onQuickLog` is provided opens the `QuickFoodLogSheet` as a modal bottom sheet without closing the search delegate.
2. **After saving/cancelling** the quick-log sheet, the search delegate closes automatically (as it does now with the button).
3. **The trailing `Icons.add_circle_outline` button is removed** from food list items when `onQuickLog` is provided.
4. **Recipe form** (`RecipeFormScreen`) is unaffected — tapping a food still selects it and returns to the quantity dialog; no trailing button is shown.
5. **No regression**: barcode scanner, "Create custom food", web search results, and swipe-to-dismiss all work as before.

---

## Implementation plan

In `_LocalSearchContent.build()`:

1. Change the `ListTile.onTap`:
   ```dart
   // Before:
   onTap: () => onSelectItem(item),
   // After:
   onTap: () => onQuickLog != null ? onQuickLog!(item) : onSelectItem(item),
   ```

2. Remove the trailing `IconButton` (lines 218–224 in `food_search_delegate.dart`). Set `trailing: null` (or simply remove the `trailing` parameter).

No changes needed in `_WebSearchContent` (it has no trailing button for quick-log, and behavior is fine).

---

## Testing

### Manual verification

1. Open food search from the log screen
2. Tap a food in "My Foods" list — quick-log sheet should open, search should remain visible underneath
3. Tap "Log to today" — sheet closes, search closes, back to log screen with new entry
4. Open search again, repeat but dismiss the sheet without saving — search should remain open
5. Verify the trailing `+` icon button is gone
6. Open search from recipe form — tapping a food should still return to the quantity dialog

### Regression verification

- Run `flutter test > test.log 2>&1` — all existing tests must pass
- Run `flutter analyze > analyze.log 2>&1` — zero issues
