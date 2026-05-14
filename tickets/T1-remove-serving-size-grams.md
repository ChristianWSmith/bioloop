# T1: Remove vestigial `servingSizeGrams` column

## Context & Discovery

`servingSizeGrams` is a nullable `REAL` column on the `foods` table. It was part of schema v1 before `servingQuantity` + `servingUnit` were split out. In the current schema (v2), it's purely informational/historical.

**Key finding:** `servingSizeGrams` is **never used in any calculation or display**. All macro scaling uses only `servingQuantity`:
```
macroPerServing * (qty / servingQuantity)
```

The only place it appears in the UI is the manual food form field labeled "Grams per serving (optional)", which is redundant when the serving unit is already "g" and confusing otherwise.

**Usage inventory** (from DISCOVERY.md §1):
- Column definition: `lib/core/database/tables/foods.dart:8`
- Manual form input: `lib/features/logging/widgets/manual_food_form.dart:29,43,131-133,150-152,340-354`
- Log screen pass-through: `lib/features/logging/log_food_screen.dart:132,283`
- ServingSizePicker unused param: `lib/features/logging/widgets/serving_size_picker.dart:11,19`
- FoodSearchItem model: `lib/providers/food_search_provider.dart:16,30,45,59,104`
- FoodResult API model: `lib/core/api/models/food_result.dart:4,17,43,53,64,76`
- Migration SQL: `lib/core/database/database.dart:51,55`
- Recipe form pass-through: `lib/features/recipes/recipe_form_screen.dart:119`

## Intent

Remove the `servingSizeGrams` field entirely — column, form field, model properties, parser output, and migration logic. Eliminates user confusion ("why do I need to enter grams when my serving is already in grams?") and removes dead code.

## Acceptance Criteria

1. `foods` table no longer has `serving_size_grams` column (v2→v3 migration drops it)
2. Manual food form no longer shows "Grams per serving (optional)" field
3. `ServingSizePicker` no longer has a `servingSizeGrams` parameter
4. `FoodResult.fromJson()` no longer parses `gramEquivalent` from serving-size strings
5. `FoodSearchItem` no longer has `servingSizeGrams` property
6. `FoodResult` no longer has `servingSizeGrams` property
7. Migration v1→v2 no longer references `serving_size_grams` for backfill (column will be dropped; migration only exists for existing DBs on upgrade path)
8. All existing foods retain their other columns (name, macros, servingQuantity, servingUnit, etc.)
9. `flutter analyze` passes with zero issues
10. All existing tests pass (237+); test seed data updated to remove `servingSizeGrams`

## Files to modify

| File | Change |
|------|--------|
| `lib/core/database/tables/foods.dart` | Delete `servingSizeGrams` column |
| `lib/core/database/database.dart` | Add v2→v3 migration (drop column); update v1→v2 migration to not reference it |
| `lib/features/logging/widgets/manual_food_form.dart` | Remove `_servingSizeController`, field widget, DB write |
| `lib/features/logging/widgets/serving_size_picker.dart` | Remove param |
| `lib/features/logging/log_food_screen.dart` | Remove write and pass-through |
| `lib/providers/food_search_provider.dart` | Remove property, constructor param, factory code |
| `lib/core/api/models/food_result.dart` | Remove property, `gramEquivalent` from parser output, fallback |
| `lib/features/recipes/recipe_form_screen.dart` | Remove pass-through |
| `test/features/logging/manual_food_form_test.dart` | Update assertions |
| `test/features/logging/log_food_screen_test.dart` | Update seed data |
| `test/features/recipes/recipes_test.dart` | Update seed data |
| `test/providers/food_search_provider_test.dart` | Update test data |
| `test/api/open_food_facts_client_test.dart` | Update expectations |
| `AGENTS.md` | Update column count in schema (13 → 12 columns) |

## Testing

1. Run `dart run build_runner build` to regenerate drift code
2. `flutter analyze > analyze.log 2>&1` — zero issues
3. `flutter test > test.log 2>&1` — all pass
4. Manual: Create a food in the manual form → verify "Grams per serving" field is gone → log it → verify macro calculations match expected
5. Manual: Search OFF food with serving size "100g" → log it → verify correct macro display
