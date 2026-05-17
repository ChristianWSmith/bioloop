# Ticket 002: Clamp OpenFoodFacts calorie values to macro maximum

**Issue:** #1 from issues.txt
**Size:** Small (~30 min)
**Dependencies:** None

## Problem

OpenFoodFacts API returns foods with calorie values that don't match the 4-4-9 macro calculation. Example from the issue: white rice with 10g carbs + 1g protein + 0g fat = 44 cal from macros, but API reports 170 cal. These inflated values enter the local database unchecked and corrupt all downstream calorie tracking.

Foods should be allowed to have *less* than their macro-calorie count (sugar alcohols, fiber contribute fewer calories), but never *more*.

## Root Cause

No validation exists in either of the two code paths that save OpenFoodFacts foods to the database:

1. `FoodSearchService.saveApiResult()` — `lib/providers/food_search_provider.dart:105-120`
2. `QuickFoodLogSheet._log()` inline insert — `lib/features/logging/widgets/quick_food_log_sheet.dart:57-72`

Values flow: API → `FoodResult.fromJson()` → `FoodSearchItem` → `db.insertFood()` with zero transformation.

## Acceptance Criteria

- [ ] New utility function `clampCaloriesToMacros()` returns `min(calories, protein*4 + carbs*4 + fat*9)`
- [ ] OpenFoodFacts foods saved via `saveApiResult()` have clamped calories
- [ ] OpenFoodFacts foods saved via `QuickFoodLogSheet._log()` inline insert have clamped calories
- [ ] Manual foods (created via `ManualFoodForm`) are NOT affected — users can enter whatever they want
- [ ] Foods with calories *below* macro-calories (sugar alcohols) are preserved as-is
- [ ] Foods with zero macros and non-zero calories are clamped to 0
- [ ] Unit tests cover: normal case, over-inflated, under-calculated, zero macros, negative guard
- [ ] `flutter analyze` passes with zero new issues
- [ ] All existing tests pass

## Files to Change

| File | Change |
|------|--------|
| `lib/core/utils/calorie_clamp.dart` | **New file** — `clampCaloriesToMacros({required double calories, required double protein, required double carbs, required double fat}) → double` |
| `lib/providers/food_search_provider.dart` | Call `clampCaloriesToMacros` on `caloriesPerServing` in `saveApiResult()` before `db.insertFood()` |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | Call `clampCaloriesToMacros` on `food.caloriesPerServing` in the inline `db.insertFood()` call (line 63) |
| `test/core/utils/calorie_clamp_test.dart` | **New file** — unit tests for the clamp utility |

## Testing

New unit tests in `test/core/utils/calorie_clamp_test.dart`:

| Test | Input | Expected |
|------|-------|----------|
| Normal (calories == macros) | cal=200, P=10, C=20, F=8 | 200 (10*4+20*4+8*9=192, min(200,192)=192) |
| Over-inflated (API bug) | cal=170, P=1, C=10, F=0 | 44 (1*4+10*4+0*9=44) |
| Under-calculated (sugar alcohols) | cal=50, P=0, C=20, F=0 | 50 (0*4+20*4+0*9=80, min(50,80)=50) |
| Zero macros, non-zero calories | cal=100, P=0, C=0, F=0 | 0 |
| All zeros | cal=0, P=0, C=0, F=0 | 0 |
| Negative guard | cal=-10, P=0, C=0, F=0 | 0 (clamp to >= 0) |

## Notes

- Only applies to foods with `source == 'open_food_facts'`. Manual foods are user-entered and should not be clamped.
- The clamp should be applied at the point of insert, not at the point of display, so the stored value is always correct.
- Consider: should we also clamp when updating an existing food via `updateFoodById()`? Currently the manual food form allows free editing, so no — only the OFF import paths need clamping.
