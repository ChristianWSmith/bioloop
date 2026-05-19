# Ticket 4: Web search tap → open form instead of immediate log

## Status
- [ ] Not started

## Scope
`lib/features/logging/widgets/food_search_delegate.dart`
`lib/features/logging/widgets/manual_food_form.dart` (minor fix)

## Context
Currently, tapping a web search result in "Search the Web" mode immediately logs the food via `QuickFoodLogSheet`. This gives users no chance to review or adjust the values from OpenFoodFacts before logging. Sometimes API values need correction (wrong serving size, inaccurate macros, etc.).

## Current Flow
```
Tap web result → onSelectItem(item) → close(delegate, item)
  → CombinedLogScreen._onSearch → _showQuickLogSheet(result)
    → QuickFoodLogSheet → db.insertEntry() → logged
```

## New Flow
```
Tap web result → open ManualFoodForm(existingFood: syntheticFood)
  → user edits/saves → db.insertFood() → return to search delegate (stays open)
    → newly saved food appears in "My Foods" list
```

## Requirements

### food_search_delegate.dart
- Pass `onCreateCustomFood` callback down to `_WebSearchContent`
- Add new callback `onCreateCustomFoodForWeb` that opens the form without closing the delegate
- On tap of a web item:
  1. Build a synthetic `Food` from the `FoodSearchItem` with `id: -1` (sentinel)
  2. Open `ManualFoodForm(existingFood: syntheticFood)`
  3. After form closes, increment `dataTriggerProvider` to refresh the local food list
  4. Do NOT close the search delegate

### manual_food_form.dart
- Fix the save condition to handle web pre-fills:
  - Current: `if (widget.existingFood != null)` → update path
  - New: `if (widget.existingFood != null && widget.existingFood!.id > 0)` → update path
  - Otherwise → insert path (handles both `existingFood == null` and `existingFood.id <= 0`)

## Acceptance Criteria
- [ ] Tapping a web result opens ManualFoodForm pre-filled with the food's data
- [ ] All fields are pre-filled: name, quantity, unit, calories, protein, carbs, fat, brand
- [ ] User can edit any field before saving
- [ ] Saving inserts a new food into the database (not update)
- [ ] After save, the search delegate remains open
- [ ] The newly saved food appears in the "My Foods" list
- [ ] User can cancel the form (back button) without side effects
- [ ] Barcode scanner path is unaffected (still logs immediately)
- [ ] Recipe form search path is unaffected (still returns item via onSelectItem)
- [ ] `flutter analyze` passes with zero issues
- [ ] `flutter test` passes with zero failures

## Testing
- **Widget test** (`test/features/logging/search_delegate_test.dart`):
  - Switch to "Search the Web", type query, tap a result
  - Verify ManualFoodForm opens with pre-filled fields
  - Save the form → verify delegate stays open
  - Switch to "My Foods" → verify the new food appears in the list
  - Test cancel (back button) → verify no food was saved

## Files to Modify
- `lib/features/logging/widgets/food_search_delegate.dart`
- `lib/features/logging/widgets/manual_food_form.dart`

## Notes
- The `id: -1` sentinel is safe because no real food has a negative ID (auto-increment starts at 1)
- The `ManualFoodForm` fix (`id > 0` check) is a one-line change with no regressions — editing real foods still uses `id > 0`, so the update path is unchanged
- `dataTriggerProvider` increment ensures `localFoodListProvider` reactively refreshes (it already watches `dataTriggerProvider`)
- This does NOT change the barcode scanner flow, which calls `onQuickLog` directly
- This does NOT change the recipe form path, which uses `onSelectItem` as fallback when `onQuickLog` is null
