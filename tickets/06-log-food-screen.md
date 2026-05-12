# T6 — Log food screen

The main food-logging UI: search → select → adjust servings → pick meal type → save.

## Files to create

- `lib/features/logging/widgets/food_search_delegate.dart` — search delegate combining local + API + manual
- `lib/features/logging/widgets/serving_size_picker.dart` — adjust servings (or grams)
- `lib/features/logging/widgets/meal_type_selector.dart` — breakfast/lunch/dinner/snack
- `lib/providers/food_log_provider.dart` — insert and query `food_entries`

## Flow

1. User taps search bar → `FoodSearchDelegate` opens
2. Shows "Create custom food" option at top
3. User types → search local foods (instant) + query OpenFoodFacts via T4 provider
4. User taps a result → serving picker shows:
   - Default: serving count = 1
   - Stepper buttons (0.5, 1, 1.5, 2, etc.)
   - If `serving_size_grams` is known, show an optional gram input that converts to fractional servings
 5. Meal type selector: segmented button (breakfast / lunch / dinner / snack). **Save button is disabled until a meal type is selected** (follows the PLAN.md §6 philosophy: prevent errors, not validate after).
 6. Save button → computes macros (`calories = calories_per_serving × servings`, etc.)
    - Inserts into `food_entries` (denormalized snapshot)
    - For API-sourced foods: auto-saves to `foods` cache
    - On success: pops back to dashboard
    - On failure (DB error, constraint violation): shows error dialog per PLAN.md §6

## DAO methods for `food_entries`

- `Future<void> insertEntry(FoodEntry entry)`
- `Future<List<FoodEntry>> getEntriesForDate(DateTime date)`
- `Future<void> deleteEntry(int id)`

## Provider: `food_log_provider.dart`

In addition to the DAO methods above, this file also exposes:

- **`todaysFoodProvider`** — an aggregate provider that calls `getEntriesForDate(today)` and sums macro totals. Used by T11 (dashboard) for the progress rings. "Today" is defined as the calendar date in the device's local timezone (not a rolling 24h window).

The provider re-emits whenever the `food_entries` table changes (drift's `table.streamUpdates` or manual invalidation).

## Acceptance criteria

- Can search and select a food
- Can adjust servings and see live macro totals update
- Gram input correctly converts to servings when `serving_size_grams` is known
- Can pick meal type
- Save creates a correct `food_entries` row
- Saved food appears on dashboard totals (next ticket)

## Testing

- **Widget — search delegate**: typing a query shows results from local foods + API (mocked)
- **Widget — serving stepper**: tap "+" increases servings to 2, macro totals displayed double
- **Widget — gram input**: when `serving_size_grams` is known, entering "150g" converts to correct fractional servings (1.5 for a 100g base)
- **Widget — meal type selector**: tapping a meal type highlights it, default is no selection; Save button is disabled until one is selected
- **Widget — save disabled without meal type**: fill all other fields, verify Save button is disabled/grayed out
- **Widget — save**: select a meal type, tap save, verify `food_entries` row created with scaled macros matching `calories_per_serving × servings`
- **Widget — API food auto-cache**: selecting an API-sourced food calls `insertFood` on the `foods` cache
- **Widget — save error shows dialog**: inject a DB write failure, tap save, verify an error dialog appears with a dismiss button
- **Unit — macro scaling**: `FoodEntry` macro computation matches `food.macro × servings` for all 4 macro fields
- **Integration — save → dashboard**: after saving, `todaysFoodProvider` emits the new entry in its list

Use `ProviderScope` overrides with in-memory DB. Mock the OpenFoodFacts API client for predictable search results.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Search bar opens the search delegate, typing shows results
- [ ] "Create custom food" option appears in search results
- [ ] Select a food → serving picker shows with default "1" serving
- [ ] Tapping "+" increments servings, macro totals update live
- [ ] Gram input: for a food with `serving_size_grams=100`, entering "150g" converts to 1.5 servings
- [ ] Meal type selector allows exactly one selection, default is unselected; Save button is grayed out/disabled until one is selected
- [ ] Save creates a `food_entries` row — verify macros are `food.macro × servings`
- [ ] API food auto-caches to `foods` table on save
- [ ] After save, navigating back to Dashboard shows the entry in totals (once T11 is done)
- [ ] All widget + unit tests pass
- [ ] Edge case: same food logged twice creates two separate `food_entries` rows

## Dependencies

T2 (app shell / placeholder exists), T4 (local food search), T5 (manual food form)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T6 — Log food screen | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
