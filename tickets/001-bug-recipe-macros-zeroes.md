# Ticket #1: [BUG] Recipe macros show zeroes after editing

**Priority:** 🔴 Critical  
**Effort:** Small (2-3 hours)  
**Status:** Pending  
**Assignee:** Unassigned  
**Created:** May 16, 2026  
**Tags:** `bug`, `recipes`, `critical`

---

## Problem Statement

When editing an existing recipe, the save logic deletes all ingredients but fails to re-insert them. This causes `computeRecipeMacros()` to return all zeroes, which then propagates to food entries when logging the recipe.

**User Impact:** After editing any recipe, all macros display as zero and logging the recipe creates entries with zero calories/macros.

---

## Root Cause

**File:** `lib/features/recipes/recipe_form_screen.dart:204-217`

The `_save()` method has two paths:

**Create path (works correctly):**
```dart
final recipeId = await db.insertRecipe(RecipesCompanion.insert(...));
for (final item in _ingredients) {
  await db.insertIngredient(RecipeIngredientsCompanion.insert(
    recipeId: recipeId,  // ✓ Uses new ID
    foodId: item.ingredient.foodId,
    quantity: item.ingredient.quantity,
    createdAt: now,
  ));
}
```

**Update path (broken):**
```dart
if (widget.recipeId != null) {
  await db.updateRecipe(widget.recipeId!, RecipesCompanion(...));
  await db.deleteIngredientsForRecipe(widget.recipeId!);  // ✓ Deletes all
  // ✗ MISSING: Re-insert ingredients loop!
}
```

After deleting ingredients, the update path does not re-insert them, leaving the recipe with no ingredients.

---

## Acceptance Criteria

### Functional
- [ ] Edit existing recipe → modify ingredients (add/remove/change quantity) → save → ingredients persist
- [ ] Edit existing recipe → change only name/serving size → save → ingredients persist unchanged
- [ ] Edit existing recipe → save → macro preview shows correct values (not zeroes)
- [ ] Log edited recipe → food entry has correct macros (calories, protein, carbs, fat)
- [ ] Create new recipe → add ingredients → save → works as before (regression test)

### Edge Cases
- [ ] Edit recipe → remove all ingredients → save button disabled (existing behavior via `_canSave`)
- [ ] Edit recipe → change ingredient quantities → save → macros recalculate correctly
- [ ] Edit recipe with per-100g ingredients → save → macros scale correctly

### Non-Functional
- [ ] No console errors or warnings during edit → save flow
- [ ] Save operation completes within 2 seconds for recipes with 10+ ingredients
- [ ] Error dialog shown if save fails (existing error handling)

---

## Technical Implementation

### Files to Modify

1. **`lib/features/recipes/recipe_form_screen.dart`** (lines 204-217)
   - Add ingredient re-insert loop after `deleteIngredientsForRecipe()`

2. **`test/features/recipes/recipes_test.dart`**
   - Add test: `edit recipe → save → verify ingredients persist`
   - Add test: `edit recipe → save → verify macros are correct`

### Code Change

**Location:** `recipe_form_screen.dart:204-217` (inside `_save()` method)

**Current code:**
```dart
if (widget.recipeId != null) {
  await db.updateRecipe(
    widget.recipeId!,
    RecipesCompanion(
      name: Value(_nameController.text.trim()),
      servingSize: Value(servingSize),
      servingLabel: Value(_servingLabelController.text.trim()),
      updatedAt: Value(now),
    ),
  );
  await db.deleteIngredientsForRecipe(widget.recipeId!);
  // MISSING: Re-insert ingredients here
}
```

**Fixed code:**
```dart
if (widget.recipeId != null) {
  await db.updateRecipe(
    widget.recipeId!,
    RecipesCompanion(
      name: Value(_nameController.text.trim()),
      servingSize: Value(servingSize),
      servingLabel: Value(_servingLabelController.text.trim()),
      updatedAt: Value(now),
    ),
  );
  await db.deleteIngredientsForRecipe(widget.recipeId!);
  
  // Re-insert ingredients
  for (final item in _ingredients) {
    await db.insertIngredient(RecipeIngredientsCompanion.insert(
      recipeId: widget.recipeId!,
      foodId: item.ingredient.foodId,
      quantity: item.ingredient.quantity,
      createdAt: now,
    ));
  }
}
```

---

## Testing Plan

### Unit Tests (Add to `test/features/recipes/recipes_test.dart`)

**Test 1: Edit recipe preserves ingredients**
```dart
testWidgets('edit recipe → save → ingredients persist', (tester) async {
  final db = createSeedDb();
  addTearDown(() => db.close());
  final now = DateTime.now().toIso8601String();

  // Create recipe with 2 ingredients
  final recipeId = await db.insertRecipe(RecipesCompanion.insert(
    name: 'Original',
    servingSize: 400,
    servingLabel: 'g',
    createdAt: now,
    updatedAt: now,
  ));
  final chicken = await (db.select(db.foods)..where((f) => f.name.equals('Chicken Breast'))).getSingle();
  final rice = await (db.select(db.foods)..where((f) => f.name.equals('Brown Rice'))).getSingle();
  
  await db.insertIngredient(RecipeIngredientsCompanion.insert(
    recipeId: recipeId, foodId: chicken.id, quantity: 2, createdAt: now,
  ));
  await db.insertIngredient(RecipeIngredientsCompanion.insert(
    recipeId: recipeId, foodId: rice.id, quantity: 1, createdAt: now,
  ));

  // Navigate to edit screen, modify, save
  await tester.pumpWidget(buildTestApp(db, recipeId: recipeId));
  await tester.pumpAndSettle();
  
  // Verify ingredients loaded
  expect(find.text('Chicken Breast'), findsOneWidget);
  expect(find.text('Brown Rice'), findsOneWidget);
  
  // TODO: Test editing flow (requires search mock)
});
```

**Test 2: Edit recipe → macros correct**
```dart
test('edit recipe → save → macros recalculate', () async {
  final db = createSeedDb();
  addTearDown(() => db.close());
  final now = DateTime.now().toIso8601String();

  final recipeId = await db.insertRecipe(RecipesCompanion.insert(
    name: 'Test',
    servingSize: 400,
    servingLabel: 'g',
    createdAt: now,
    updatedAt: now,
  ));
  final chicken = await (db.select(db.foods)..where((f) => f.name.equals('Chicken Breast'))).getSingle();
  
  await db.insertIngredient(RecipeIngredientsCompanion.insert(
    recipeId: recipeId, foodId: chicken.id, quantity: 2, createdAt: now,
  ));

  // Verify initial macros
  final macros1 = await db.computeRecipeMacros(recipeId);
  expect(macros1.calories, closeTo(330, 0.01));

  // Simulate edit: change quantity from 2 to 3
  await db.deleteIngredientsForRecipe(recipeId);
  await db.insertIngredient(RecipeIngredientsCompanion.insert(
    recipeId: recipeId, foodId: chicken.id, quantity: 3, createdAt: now,
  ));

  // Verify updated macros
  final macros2 = await db.computeRecipeMacros(recipeId);
  expect(macros2.calories, closeTo(495, 0.01));  // 165 * 3 = 495
});
```

### Manual Testing Checklist

1. **Create recipe flow (regression)**
   - [ ] Create new recipe with 3 ingredients
   - [ ] Save → verify macro preview shows correct values
   - [ ] Log recipe → verify food entry has correct macros

2. **Edit recipe flow (primary fix)**
   - [ ] Edit recipe → change name only → save → verify ingredients unchanged
   - [ ] Edit recipe → change ingredient quantity → save → verify macros updated
   - [ ] Edit recipe → add new ingredient → save → verify ingredient appears
   - [ ] Edit recipe → remove ingredient → save → verify ingredient gone
   - [ ] Log edited recipe → verify macros are correct (not zeroes)

3. **Edge cases**
   - [ ] Edit recipe → remove all ingredients → save button disabled
   - [ ] Edit recipe with per-100g food → save → macros scale correctly
   - [ ] Edit recipe multiple times → verify no data corruption

---

## Definition of Done

- [ ] Code change implemented
- [ ] Unit tests added and passing
- [ ] Manual testing checklist complete
- [ ] No regressions in existing recipe tests (`flutter test test/features/recipes/`)
- [ ] `flutter analyze` passes with zero issues
- [ ] Code reviewed (if applicable)

---

## Dependencies

- None (isolated bug fix)

---

## References

- Discovery report: `DISCOVERY.md` (Issue #2 section)
- Related files:
  - `lib/features/recipes/recipe_form_screen.dart:195-259`
  - `lib/core/database/database.dart:353-391`
  - `test/features/recipes/recipes_test.dart:140-168`

---

## Notes

**Discovery Finding:** This bug was not caught by existing tests because:
- Tests cover create → save → verify macros ✓
- Tests cover edit mode UI loading ✓
- **Missing:** Edit → save → verify macros (integration gap)

**Post-Fix:** Consider adding integration test for full edit flow to prevent regression.
