# Ticket 4: Apply Calorie Clamping at OpenFoodFacts Import Time

**Priority:** High (user-facing bug)  
**Risk:** Low  
**Effort:** ~45 minutes  
**Status:** ⬜ Pending  

---

## Context

When a user logs a food directly from OpenFoodFacts, the food appears in the log with **unclamped** (potentially inflated) calorie values. The calorie clamping logic (`clampCaloriesToMacros`) only runs when saving to the local database, but the preview in `QuickFoodLogSheet` shows the original API values.

From `issues.txt`:
> currently, we clamp calories while ingesting foods from openfoodfacts. we do this because some foods on openfoodfacts have overinflated calories in relation to their macros. we don't do it when the calories are lower than what they might appear to be based off of their macros due to things like sugar alcohols and fiber, which may inflate the macros while not meaningfully contributing to calories. currently, we're doing a good job of correcting these issues during the import to our local database, but we're not catching it in time before the food gets logged. basically, when the user logs something directly from openfoodfacts, it hits the log with the incorrect values before being saved locally with the correct values. we want to ensure that the values get corrected BEFORE hitting the log

**Example:**
- OpenFoodFacts API returns: 170 calories, 10g carbs, 1g protein, 0g fat
- Macro calories: (10×4) + (1×4) + (0×9) = 44 calories
- **Current behavior:** User sees 170 cal in preview, saves 44 cal to DB (mismatch!)
- **Expected behavior:** User sees 44 cal in preview, saves 44 cal to DB (consistent)

---

## Current Flow (Broken)

```
OpenFoodFacts API (170 cal)
    ↓
FoodResult.fromJson() — copies 170 cal
    ↓
FoodSearchItem.fromFoodResult() — copies 170 cal
    ↓
QuickFoodLogSheet — shows 170 cal preview ❌
    ↓
User taps "Log entry"
    ↓
_log() method — clamps to 44 cal HERE (too late!)
    ↓
Database — saves 44 cal ✓
```

**Problem:** User sees 170 cal but database has 44 cal. This creates confusion and distrust.

---

## Required Changes

### Change 1: Clamp in `FoodSearchItem.fromFoodResult()`

**File:** `lib/providers/food_search_provider.dart`

**Lines 57-69:** Modify the factory to clamp calories at import time

```dart
// OLD:
factory FoodSearchItem.fromFoodResult(FoodResult result) => FoodSearchItem(
  name: result.name,
  servingLabel: result.servingLabel,
  servingQuantity: result.servingQuantity,
  servingUnit: result.servingUnit,
  caloriesPerServing: result.caloriesPerServing,  // ← Unclamped!
  proteinPerServing: result.proteinPerServing,
  carbsPerServing: result.carbsPerServing,
  fatPerServing: result.fatPerServing,
  barcode: result.barcode,
  brand: result.brand,
  source: result.source,
);

// NEW:
factory FoodSearchItem.fromFoodResult(FoodResult result) {
  final clampedCalories = clampCaloriesToMacros(
    calories: result.caloriesPerServing,
    protein: result.proteinPerServing,
    carbs: result.carbsPerServing,
    fat: result.fatPerServing,
  );
  return FoodSearchItem(
    name: result.name,
    servingLabel: result.servingLabel,
    servingQuantity: result.servingQuantity,
    servingUnit: result.servingUnit,
    caloriesPerServing: clampedCalories,  // ← Clamped at import!
    proteinPerServing: result.proteinPerServing,
    carbsPerServing: result.carbsPerServing,
    fatPerServing: result.fatPerServing,
    barcode: result.barcode,
    brand: result.brand,
    source: result.source,
  );
}
```

### Change 2: Remove Duplicate Clamping from QuickFoodLogSheet

**File:** `lib/features/logging/widgets/quick_food_log_sheet.dart`

**Lines 58-79:** Remove the clamping logic (now redundant)

```dart
// REMOVE THIS BLOCK:
if (foodId == null && food.source == 'open_food_facts') {
  final clampedCalories = clampCaloriesToMacros(
    calories: food.caloriesPerServing,
    protein: food.proteinPerServing,
    carbs: food.carbsPerServing,
    fat: food.fatPerServing,
  );
  foodId = await db.insertFood(FoodsCompanion.insert(
    name: food.name,
    servingLabel: food.servingLabel,
    servingQuantity: Value(food.servingQuantity),
    servingUnit: Value(food.servingUnit),
    caloriesPerServing: clampedCalories,
    proteinPerServing: food.proteinPerServing,
    carbsPerServing: food.carbsPerServing,
    fatPerServing: food.fatPerServing,
    barcode: Value(food.barcode),
    brand: Value(food.brand),
    source: Value(food.source),
    createdAt: now,
  ));
}
```

**Replace with simplified logic:**
```dart
// NEW: Just save the food (already clamped in fromFoodResult)
if (foodId == null && food.source == 'open_food_facts') {
  foodId = await db.insertFood(FoodsCompanion.insert(
    name: food.name,
    servingLabel: food.servingLabel,
    servingQuantity: Value(food.servingQuantity),
    servingUnit: Value(food.servingUnit),
    caloriesPerServing: food.caloriesPerServing,  // Already clamped
    proteinPerServing: food.proteinPerServing,
    carbsPerServing: food.carbsPerServing,
    fatPerServing: food.fatPerServing,
    barcode: Value(food.barcode),
    brand: Value(food.brand),
    source: Value(food.source),
    createdAt: now,
  ));
}
```

**Note:** The food's `caloriesPerServing` is already clamped, so no need to call `clampCaloriesToMacros` again.

---

## Acceptance Criteria

- [ ] OFF foods show clamped calories in search results immediately
- [ ] QuickFoodLogSheet preview displays clamped values (matches saved values)
- [ ] Saved database values match preview (no discrepancy)
- [ ] Sugar alcohol foods (calories < macro calories) preserved as-is
- [ ] Manual foods (non-OFF) unaffected by clamping
- [ ] `flutter analyze` passes with zero issues
- [ ] All existing tests pass
- [ ] New tests verify clamped values in preview and database

---

## Testing

### Unit Tests to Add

**File:** `test/providers/food_search_provider_test.dart`

**Test 1: fromFoodResult clamps inflated calories**
```dart
test('fromFoodResult clamps inflated calories from API', () {
  final result = FoodResult(
    name: 'Test Food',
    servingLabel: '100g',
    caloriesPerServing: 170,  // Inflated
    proteinPerServing: 10,     // 40 cal
    carbsPerServing: 1,        // 4 cal
    fatPerServing: 0,          // 0 cal
    barcode: '123',
  );

  final item = FoodSearchItem.fromFoodResult(result);

  // Macro calories = 10*4 + 1*4 + 0*9 = 44
  expect(item.caloriesPerServing, 44);  // Clamped to macro max
  expect(item.source, 'open_food_facts');
});
```

**Test 2: fromFoodResult preserves sugar alcohol foods**
```dart
test('fromFoodResult preserves foods with calories below macro max', () {
  final result = FoodResult(
    name: 'Sugar Free Candy',
    servingLabel: '100g',
    caloriesPerServing: 10,   // Lower than macro calc (sugar alcohols)
    proteinPerServing: 0,
    carbsPerServing: 50,      // Would be 200 cal, but sugar alcohols
    fatPerServing: 0,
    barcode: '456',
  );

  final item = FoodSearchItem.fromFoodResult(result);

  // Calories (10) < macro max (200), so preserved as-is
  expect(item.caloriesPerServing, 10);  // Not clamped
});
```

**Test 3: fromFoodResult handles normal foods correctly**
```dart
test('fromFoodResult preserves accurate calorie values', () {
  final result = FoodResult(
    name: 'Chicken Breast',
    servingLabel: '100g',
    caloriesPerServing: 165,  // Accurate
    proteinPerServing: 31,     // 124 cal
    carbsPerServing: 0,        // 0 cal
    fatPerServing: 3.6,        // 32.4 cal
    barcode: '789',
  );

  final item = FoodSearchItem.fromFoodResult(result);

  // Macro calories ≈ 156, API says 165 (close enough, within rounding)
  expect(item.caloriesPerServing, lessThanOrEqualTo(165));
});
```

### Widget Test (Optional but Recommended)

**File:** `test/features/logging/widgets/quick_food_log_sheet_test.dart`

Create a new test file to verify the preview shows clamped values:

```dart
test('QuickFoodLogSheet shows clamped calories for OFF foods', () async {
  final food = FoodSearchItem(
    name: 'Test Food',
    servingLabel: '100g',
    caloriesPerServing: 44,  // Already clamped
    proteinPerServing: 10,
    carbsPerServing: 1,
    fatPerServing: 0,
    source: 'open_food_facts',
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: QuickFoodLogSheet(food: food),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Verify preview shows 44 cal (not 170)
  expect(find.textContaining('44 cal'), findsOneWidget);
});
```

### Commands
```bash
flutter analyze
flutter test test/providers/food_search_provider_test.dart
flutter test test/features/logging/widgets/quick_food_log_sheet_test.dart  # if created
```

---

## Files to Modify

| File | Lines Changed | Type |
|------|---------------|------|
| `lib/providers/food_search_provider.dart` | ~12 (add clamp logic to factory) | Production |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | ~7 (remove duplicate clamp) | Production |
| `test/providers/food_search_provider_test.dart` | ~50 | Test |
| `test/features/logging/widgets/quick_food_log_sheet_test.dart` | ~40 | Test (optional) |

**Total:** ~19 production lines, ~90 test lines

---

## Implementation Notes

- The clamping logic (`clampCaloriesToMacros`) already exists and is well-tested
- This change moves the clamping **earlier** in the flow (at import, not at save)
- All downstream consumers (search results, preview, save) will see consistent values
- Manual foods (created by user) are not affected — they already have accurate calories
- Sugar alcohol foods (calories < macro max) are preserved correctly

---

## Edge Cases

1. **Inflated API calories** → Clamped to macro max ✓
2. **Sugar alcohol foods** → Preserved as-is (calories < macro max) ✓
3. **Accurate API calories** → Preserved (already ≤ macro max) ✓
4. **Manual foods** → Not affected (source != 'open_food_facts') ✓
5. **Barcode scanner** → Uses same `fromFoodResult()` factory, so clamped ✓

---

## References

- `DISCOVERY.md` — Issue 1 section
- `lib/core/utils/calorie_clamp.dart` — Clamping utility
- `lib/providers/food_search_provider.dart:57-69` — fromFoodResult factory
- `lib/features/logging/widgets/quick_food_log_sheet.dart:58-79` — Duplicate clamping
- `test/core/utils/calorie_clamp_test.dart` — Existing clamp tests
- `issues.txt:1` — Original issue
