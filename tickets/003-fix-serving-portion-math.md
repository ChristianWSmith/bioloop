# Ticket 3 — Fix serving/portion macro math

- **Issues:** #1, #3
- **Priority:** High
- **Effort:** Medium (~4 files, ~10 formula sites)
- **Dependencies:** Must be done **after** Ticket 2 (removes template code from `log_food_screen.dart`, reducing scope)

---

## Context

### The bug

When the OpenFoodFacts API returns a food with **no per-serving** nutriment data, `FoodResult.fromJson()` falls back to **per-100g** mode:

```dart
servingQuantity  = 100
servingUnit      = 'g'
caloriesPerServing = energy_kcal_100g   // e.g. 350 kcal per 100g
proteinPerServing  = proteins_100g      // e.g. 6.6g per 100g
```

Every macro calculation in the app uses the formula:

```dart
caloriesPerServing * quantity
```

This is correct only when `servingQuantity == 1` (i.e., "1 serving = 1 unit"). For per-100g foods, `servingQuantity = 100`, so:

- User selects "riz rond" (350 kcal / 100g)
- `_selectFood()` sets `_servings = food.servingQuantity` → 100
- Preview shows `350 × 100 = 35,000 kcal` (100× too high)
- `ServingSizePicker` shows "100" as default Qty

If the user changes Qty from 100 to 1 (intending "1 serving of 100g"), the math gives 350 kcal — correct for 100g — but the stored `servingLabel` becomes `"1 g"` instead of `"100 g"`.

The same bug affects recipe ingredients (issue #3): the `_QuantityDialog` asks for "Quantity in g", user enters 100, and `caloriesPerServing × 100` produces 100× the expected macros.

### Example

| Food | `servingQuantity` | `caloriesPerServing` | User enters | Current result | Expected result |
|------|-------------------|---------------------|-------------|----------------|-----------------|
| Chicken breast (per 100g) | 100 (g) | 165 | 200g | 33,000 kcal | 330 kcal |
| Riz rond (per 100g) | 100 (g) | 350 | 100g | 35,000 kcal | 350 kcal |
| Oats (per 1 cup) | 1 (cup) | 300 | 2 cups | 600 kcal | 600 kcal (unchanged) |

### The fix formula

All current sites:

```dart
food.caloriesPerServing * quantity
```

Should become:

```dart
food.caloriesPerServing * (quantity / food.servingQuantity)
```

This is **backward-compatible**: for `servingQuantity = 1`, `qty / 1 = qty`, producing the same result as before.

### Default servings

`_selectFood()` initializes `_servings = food.servingQuantity` which is 100 for per-100g foods. The default should be **1** (meaning "1 serving"):

```dart
_servings = 1;  // instead of food.servingQuantity
```

The user can then adjust Qty to their desired amount (e.g., 200 for 200g), and the normalized formula handles the math.

---

## Proposed fix

### All formula sites to update

#### `lib/features/logging/log_food_screen.dart`

| Line(s) | Current | Fixed |
|---------|---------|-------|
| 59 | `_servings = food.servingQuantity` | `_servings = 1` |
| 84–88 | `caloriesPerServing * _servings` | `caloriesPerServing * (_servings / food.servingQuantity)` |
| 223–226 | `food.caloriesPerServing * _servings` | `food.caloriesPerServing * (_servings / food.servingQuantity)` |
| 388–409 (4 rows) | `food.caloriesPerServing * _servings` | `food.caloriesPerServing * (_servings / food.servingQuantity)` |

#### `lib/features/recipes/recipe_form_screen.dart`

| Line(s) | Current | Fixed |
|---------|---------|-------|
| 284–287 (4 lines) | `food.caloriesPerServing * qty` | `food.caloriesPerServing * (qty / food.servingQuantity)` |

#### `lib/core/database/database.dart`

| Line(s) | Current | Fixed |
|---------|---------|-------|
| 349–352 (4 lines) | `item.food.caloriesPerServing * qty` | `item.food.caloriesPerServing * (qty / item.food.servingQuantity)` |

#### `lib/features/recipes/widgets/recipe_ingredient_row.dart`

| Line(s) | Current | Fixed |
|---------|---------|-------|
| 20 | `food.caloriesPerServing * ingredient.quantity` | `food.caloriesPerServing * (ingredient.quantity / food.servingQuantity)` |

---

## Acceptance criteria

1. **Per-100g API food**: searching "riz rond", selecting it, Qty=100, unit=g → preview shows 350 kcal (not 35,000); saving logs correct macros
2. **Per-serving food**: searching a food with `servingQuantity=1` → behavior is identical to before the fix
3. **Qty adjustment**: changing Qty from 100 to 200 on "riz rond" doubles macros from 350→700 kcal
4. **Recipe ingredient**: adding 100g of a per-100g food to a recipe → recipe totals are correct (not 100×)
5. **Recipe ingredient display**: ingredient row shows correct calories
6. **Recipe macro totals (DB)**: `computeRecipeMacros()` returns correct summed values
7. **Per-100g food default**: selecting a per-100g food shows Qty=1 initially (not Qty=100)
8. **Serving label**: saving 200g of "riz rond" stores `servingLabel = "200 g"`

---

## Testing

### New test cases

```dart
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.createInMemory();
  });

  tearDown(() => db.close());

  group('macro calculation normalization', () {
    test('per-serving food (servingQuantity=1) is unaffected', () async {
      // Insert food with servingQuantity=1, caloriesPerServing=300
      // Log with quantity=2
      // Assert entry.calories == 600
    });

    test('per-100g food (servingQuantity=100) normalizes correctly', () async {
      // Insert food with servingQuantity=100, caloriesPerServing=165
      // Log with quantity=200
      // Assert entry.calories == 330
    });

    test('recipe computeRecipeMacros normalizes ingredient qty', () async {
      // Recipe with ingredient: food has servingQuantity=100, calsPerServing=165
      // Recipe ingredient quantity=100
      // computeRecipeMacros returns total_cals == 165
    });
  });
}
```

### Existing tests

Run `flutter test` to confirm no regressions in existing tests.

---

## Risks

- **Division by zero**: `servingQuantity` has a DB default of 1.0, but if a food somehow has `0` it would crash. Add a guard: `(food.servingQuantity > 0 ? food.servingQuantity : 1)`.
- **Missed sites**: search the codebase for `caloriesPerServing *` and `proteinPerServing *` to confirm all formula locations are caught.
- **screenshot/per-UI tests**: the preview values change, which could affect golden tests if they exist (they don't in this project).
