# Ticket 006 — Serving units: UI

**Issues:** #4 (UI), #8
**Estimate:** ~3 hr
**Depends on:** Ticket 005 (schema + parsing)

---

## Acceptance criteria

### Serving size picker (#4 UI)
- [ ] `ServingSizePicker` shows quantity input + unit dropdown (replaces "Servings" stepper + conditional "Grams" field)
- [ ] Unit dropdown includes: g, ml, fl oz, oz, cups, tbsp, tsp, slices, pieces, bars, servings
- [ ] Last dropdown option is "Custom…" which opens a text field for arbitrary unit
- [ ] Macro preview updates correctly based on quantity × per-unit macros
- [ ] Logging saves correct `servings` value (quantity) and `servingLabel`

### Manual food form (#4 UI)
- [ ] "Serving label" free-text field replaced with quantity + unit dropdown
- [ ] Serving label is auto-generated from the two fields (e.g., `"2 cups"`)
- [ ] "Grams per serving" field remains as optional supplemental info (for weight-based logging)

### Recipe ingredient quantity dialog (#8)
- [ ] Dialog label shows `"Quantity in {unit}"` (e.g., "Quantity in cups") instead of "Number of servings"
- [ ] Uses the ingredient food's serving unit

### Edit entry sheet
- [ ] Shows the entry's `servingLabel` next to the quantity field for context
- [ ] Quantity field pre-populated from entry's `servings` value

---

## Context from DISCOVERY.md

### Current `ServingSizePicker`

```dart
// lib/features/logging/widgets/serving_size_picker.dart
// Shows:
//   "Servings" header
//   [-] 2 [+] stepper
//   [Grams] input (only if servingSizeGrams != null)
```

### Desired design

```
Quantity: [2  ] Unit: [cups ▾]
                        g
                        ml
                        fl oz
                        oz
                        cups
                        tbsp
                        tsp
                        slices
                        pieces
                        bars
                        servings
                        Custom…
```

Macros shown below: "2 cups × {food name}" with calculated values.

When unit is "g", the quantity is the gram amount directly (no conversion needed). For other units, the stored `servingSizeGrams` enables the optional gram equivalence conversion if needed later.

### Manual Food Form rework

Current: free-text "Serving label" field + optional "Serving size in grams".

New design:
- Quantity field (default: 1)
- Unit dropdown (default: "g")
- Auto-generated label shown as read-only preview: "Serving label: 2 cups"
- Optional "Grams per serving" field (for weight-based entries)

```dart
// Inside ManualFoodForm build:
Row(
  children: [
    Expanded(
      flex: 1,
      child: TextFormField(
        controller: _qtyController,
        decoration: InputDecoration(labelText: 'Quantity'),
        keyboardType: TextInputType.number,
      ),
    ),
    SizedBox(width: 12),
    Expanded(
      flex: 2,
      child: _buildUnitDropdown(),
    ),
  ],
),
// Preview:
Text('Label: ${_qtyController.text} ${_selectedUnit}'),
// Optional:
TextFormField(
  controller: _servingSizeGramsController,
  decoration: InputDecoration(labelText: 'Grams per serving (optional)'),
),
```

### Recipe ingredient dialog

The `_QuantityDialog` in `recipe_form_screen.dart:440` currently shows:

```dart
decoration: const InputDecoration(labelText: 'Number of servings'),
```

Should show:

```dart
decoration: InputDecoration(labelText: 'Quantity in ${food.servingUnit}'),
```

And the `food.servingUnit` should be passed into the dialog rather than hardcoding "servings".

### Recipe ingredient row display

`recipe_ingredient_row.dart:26` already shows:
```dart
'${ingredient.quantity.toStringAsFixed(1)} × ${food.servingLabel} — ${cals.toStringAsFixed(0)} kcal'
```

This is already correct — only the dialog label needs changing.

---

## Testing

### Manual test — serving picker
1. Search for and select a food with serving label "1 cup (240ml)"
2. Verify unit dropdown shows "cups", quantity defaults to 1
3. Change quantity to 2 → verify macros double
4. Change unit to "g" → quantity field stays, macros still compute correctly
5. Select "Custom…" → enter "portions" → verify unit shows "portions"

### Manual test — manual food form
1. Create custom food, enter qty=2 + unit="slices"
2. Verify serving label preview shows "2 slices"
3. Save and verify the label is correct in the database

### Manual test — recipe dialog
1. Create/edit a recipe with ingredient "Chicken Breast" (serving unit: "g")
2. Tap + to add ingredient → dialog shows "Quantity in g"
3. Tap edit on existing ingredient → dialog shows correct unit

### Automated test ideas
- Widget test: `ServingSizePicker` renders dropdown with correct options
- Widget test: changing quantity updates macro preview
- Unit test: manual food form generates correct serving label from qty + unit

---

## Files to modify

- `lib/features/logging/widgets/serving_size_picker.dart` — full rewrite
- `lib/features/logging/widgets/manual_food_form.dart` — replace serving label field
- `lib/features/recipes/recipe_form_screen.dart` — update `_QuantityDialog` label
- `lib/features/history/widgets/edit_entry_sheet.dart` — show `servingLabel`
