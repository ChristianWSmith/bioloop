# T5: Quick-log from recent foods + duplicate entries

## Context & Discovery

The log tab shows a list of recent foods (from `recentFoodsProvider`) in the search delegate. Tapping a recent food currently goes through the **full selection pipeline**: select → configure servings → choose meal type → save. This is slow for frequently-eaten foods.

The today's entries section (`_TodayEntriesSection`) shows logged entries with a delete button but no way to duplicate an entry.

**Current behavior** (from DISCOVERY.md §5):
- Recent food tap → `close(context, item)` → `_selectFood()` → full form re-renders with serving picker, macro preview, meal type → user taps Save
- Today's entries have no `onTap` — only a trash delete icon
- Recipe ingredient picker shares the same `FoodSearchDelegate` and could reuse the quick-add pattern

**No quick-log or duplicate-entry functionality exists** — grep for `quickLog`, `duplicateEntry`, `logAgain`, `reLog` returned zero results.

**Reusable components:**
- `LogRecipeSheet` (`log_recipe_sheet.dart`) — good UX template: bottom sheet with serving/portion + meal type + log button
- `_save()` in `log_food_screen.dart:117-193` — can be refactored into a reusable method
- `foodLogProvider.insertEntry()` — CRUD wrapper

## Intent

Add two convenience features:
1. **Quick-log from recent foods** — tap a "+" icon on a recent food item to open a lightweight bottom sheet (serving size + meal type) and log immediately, bypassing the full form
2. **Duplicate an entry** — tap a duplicate icon on a today's entry to create a new entry with the same data and a fresh timestamp

Recipe ingredient selection already shares the `FoodSearchDelegate` and would get the quick-add UI for free — but the recipe context needs different semantics (in-memory add, not immediate persistence). This is noted but not in scope for this ticket.

## Acceptance Criteria

### Quick-log
1. Recent food items in the search delegate show a trailing "+" icon (or equivalent affordance)
2. Tapping "+" opens a bottom sheet (`QuickFoodLogSheet`) with:
   - Food name + macro preview (calories, protein, carbs, fat)
   - Serving size field (default = `food.servingQuantity`, with the correct unit)
   - Meal type selector (breakfast/lunch/dinner/snack) — same as main form
   - "Log to today" button (disabled until meal type is selected)
3. Tapping "Log to today" immediately inserts a `food_entry` with scaled macros
4. `todaysFoodProvider` is invalidated → entry appears in today's list without refresh
5. Bottom sheet closes automatically after successful log
6. Quick-log works for both local (manual) foods and API-sourced foods (auto-inserts `Food` record if needed, same as `_save()`)

### Duplicate entry
7. Each entry in `_TodayEntriesSection` shows a trailing duplicate icon (`Icons.replay` or equivalent) alongside the delete icon
8. Tapping duplicate opens the same `QuickFoodLogSheet` pre-filled with the entry's data (servings, macros) and a prompt for meal type
9. On save, creates a new entry with the same macro values and food reference but a fresh `loggedAt` timestamp
10. `todaysFoodProvider` is invalidated → duplicate appears in today's list

### General
11. `flutter analyze` passes with zero issues
12. All existing tests pass
13. Existing full flow (tap recent food → full form with serving picker + meal type + save) remains unchanged

## Files to modify

| File | Change |
|------|--------|
| `lib/features/logging/log_food_screen.dart` | Add `_quickLog(FoodSearchItem)` method; refactor `_save()` to be reusable; add duplicate icon + handler in `_TodayEntriesSection` |
| `lib/features/logging/widgets/food_search_delegate.dart` | Add `onQuickLog` callback; add trailing "+" icon on recent food items |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | **New file** — bottom sheet widget |

### New widget: `QuickFoodLogSheet`

Modeled on `LogRecipeSheet` (`lib/features/recipes/widgets/log_recipe_sheet.dart`). It's a `ConsumerStatefulWidget` shown as a modal bottom sheet.

**Layout:**
- Food name (bold)
- Macro preview row (calories, protein, carbs, fat) — computed using the same `macroPerServing * (qty / servingQuantity)` formula
- `ServingSizePicker` — reuse existing widget; pre-filled with `food.servingQuantity`
- `MealTypeSelector` — reuse existing widget
- "Log to today" `FilledButton` — disabled until meal type is non-null

**Parameters:**
```dart
class QuickFoodLogSheet extends ConsumerStatefulWidget {
  final FoodSearchItem food;           // the food to log
  final FoodEntry? sourceEntry;        // null for fresh quick-log, non-null for duplicate
}
```

When `sourceEntry != null` (duplicate), pre-fill serving size from the original entry's `servings` field.

### Refactoring `_save()` in `log_food_screen.dart`

The current `_save()` method (lines 117–193) handles:
1. Auto-inserting `Food` record for API-sourced foods (if `localId == null && source == 'open_food_facts'`)
2. Computing scaled macros: `macroPerServing * (_servings / sq)` with zero-division guard
3. Inserting `FoodEntriesCompanion`
4. Invalidating `todaysFoodProvider`
5. Resetting form state

Steps 1–4 should be extracted into a reusable method that `_save()` and the new quick-log flow both call. The new method takes `(FoodSearchItem food, double servings, String mealType, {DateTime? loggedAt})`.

### Duplicate flow in `_TodayEntriesSection`

Each entry `ListTile` already has a trailing delete button. Add a trailing duplicate icon before the delete icon:

```dart
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: Icon(Icons.replay),
      onPressed: () => _onDuplicate(context, entry),
    ),
    IconButton(
      icon: Icon(Icons.delete),
      onPressed: () => _confirmDelete(context, entry),
    ),
  ],
),
```

`_onDuplicate()` opens `QuickFoodLogSheet` with `sourceEntry` set.

## Testing

1. `flutter test > test.log 2>&1` — all pass
2. `flutter analyze > analyze.log 2>&1` — zero issues
3. Manual:
   - Open search → "+" on recent food → bottom sheet appears → select meal type → tap "Log to today" → entry appears in list
   - Verify macro values in quick-log match the full form flow (same formula)
   - Tap duplicate icon on existing entry → bottom sheet pre-filled → select meal type → save → new entry appears with same data but new timestamp
   - Verify existing full flow (tap recent → full form) still works unchanged
   - Verify API foods that haven't been saved yet get auto-inserted into `foods` table (same as existing `_save()` behavior)
