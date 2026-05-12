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
5. Meal type selector: segmented button (breakfast / lunch / dinner / snack)
6. Save button → computes macros (`calories = calories_per_serving × servings`, etc.)
   - Inserts into `food_entries` (denormalized snapshot)
   - For API-sourced foods: auto-saves to `foods` cache
   - Pops back to dashboard

## DAO methods for `food_entries`

- `Future<void> insertEntry(FoodEntry entry)`
- `Future<List<FoodEntry>> getEntriesForDate(DateTime date)`
- `Future<void> deleteEntry(int id)`

## Acceptance criteria

- Can search and select a food
- Can adjust servings and see live macro totals update
- Gram input correctly converts to servings when `serving_size_grams` is known
- Can pick meal type
- Save creates a correct `food_entries` row
- Saved food appears on dashboard totals (next ticket)

## Dependencies

T2 (app shell / placeholder exists), T4 (local food search), T5 (manual food form)
