# Ticket 2: Fix recipe ingredient quantity defaulting to 1

**Issue:** #4  
**Priority:** High  
**Effort:** 2-3 lines  
**File:** `lib/features/recipes/recipe_form_screen.dart`

## Context

When adding ingredients to a recipe, the quantity defaults to `1` in both code paths, regardless of the food's `servingQuantity`. This is semantically wrong for per-100g foods (`servingQuantity=100`), where `1` means 1g instead of a full serving (100g).

The `AGENTS.md` convention states: "`_selectFood()` defaults to `_servings = food.servingQuantity` (not 1)." The recipe ingredient flow should follow the same convention.

### Path A — via search dialog (lines 98-106)

`showDialog<_QuantityDialog>` is called without passing `initialValue`. `_QuantityDialog.initState` (line 440) defaults to `'1'`:

```dart
_controller = TextEditingController(text: widget.initialValue ?? '1');
```

### Path B — direct from custom food form (lines 136-148)

```dart
quantity: 1,  // hardcoded
```

Both should use `food.servingQuantity` as the default.

## Acceptance criteria

- [ ] Adding a per-100g food (`servingQuantity=100`) to a recipe → quantity defaults to 100
- [ ] Adding a per-serving food (`servingQuantity=1`) to a recipe → quantity defaults to 1
- [ ] Adding a food with a custom `servingQuantity` (e.g., 30 for "per 30g") → defaults to that value
- [ ] The quantity dialog shows the correct pre-filled value
- [ ] Editing an existing ingredient's quantity still shows the stored value (not the default)
- [ ] Creating a custom food via manual form → adding it to recipe → defaults to the food's `servingQuantity`

## Testing

### Manual testing
1. Open Recipes → New Recipe → Add ingredient → search for a per-100g food (e.g., "chicken breast" from OpenFoodFacts) → verify quantity dialog shows 100
2. Add a food with serving label "per serving" (servingQuantity=1) → verify quantity dialog shows 1
3. Create a custom food → set serving size to 50g → save → add to recipe → verify quantity defaults to 50
4. Edit an existing ingredient → verify the dialog shows the previously stored quantity

### Regression checks
- Existing recipes: ingredients already saved are not affected (DB data unchanged)
- Quantity dialog cancel still returns `null` (ingredient not added)
- Parse failure fallback: if user enters invalid text, `double.tryParse(quantityStr) ?? 1` still protects against crashes

## Implementation

### Path A (line 101-103)
```dart
builder: (ctx) => _QuantityDialog(
  foodName: food.name,
  unit: food.servingUnit,
  initialValue: food.servingQuantity.toString(),  // add this
),
```

### Path B (line 143)
```dart
quantity: food.servingQuantity,  // was: 1
```
