# Ticket 5 — Auto-calculate calories from macros in manual food form

- **Priority:** Low (quality-of-life)
- **Effort:** Small (~1 file, ~15 lines)
- **Dependencies:** None

---

## Context

The manual food entry form (`manual_food_form.dart`) requires the user to enter four independent macro fields: calories, protein, carbs, and fat. Calories are stored as an independent column — they are **never derived** from the other macros anywhere in the app.

This means the user must manually compute `protein×4 + carbs×4 + fat×9` in their head or on a calculator, then type the result into the calories field. Every time they adjust any macro, they must redo the math.

Since 4-4-9 is a universal nutrition convention, the form should auto-compute calories from macros and only require manual override when the food label's stated calories don't match 4-4-9 (e.g., due to fiber, sugar alcohols, or rounding).

---

## Proposed fix

### Core logic

Add `onChanged` listeners to the protein, carbs, and fat text fields. When all three have valid non-negative numeric values, compute:

```dart
final p = double.tryParse(_proteinController.text) ?? 0;
final c = double.tryParse(_carbsController.text) ?? 0;
final f = double.tryParse(_fatController.text) ?? 0;
final computed = (p * 4) + (c * 4) + (f * 9);
```

Then update `_caloriesController.text` with the computed value — **unless** the user has manually edited the calories field.

### Override tracking

Introduce a boolean flag:

```dart
bool _caloriesManuallyEdited = false;
```

- Starts `false`
- Set to `true` when the user edits the calories field (its `onChanged` fires)
- Set to `false` if the user clears all three macro fields to zero (allows auto-compute to resume)
- When `true`, auto-compute is suppressed — the calories field shows whatever the user typed

**Why not always auto-compute?** Many food labels list calories that differ from 4-4-9 (e.g., 200 kcal from 20g protein + 10g carbs + 10g fat = 210 kcal by 4-4-9, but the label says 200 due to fiber subtraction). Override must be respected without fighting the auto-fill.

### UI change

Show a subtle indicator when calories are auto-computed. Simplest approach: append `"(calculated)"` to the calories label when `_caloriesManuallyEdited == false` and all three macros have values.

Alternatively, just auto-fill silently — the user sees the value and can adjust. The ticket recommends the silent approach as a first iteration; the indicator can be added if users report confusion.

### Form save (`_save()`)

No changes needed. The `_caloriesController.text` is already parsed in the save method — whether typed or auto-computed, the value is the same.

---

## Acceptance criteria

1. Open manual food form → fill protein=20, carbs=30, fat=10 → calories field auto-fills to `20×4 + 30×4 + 10×9 = 290`
2. Adjust protein from 20 to 25 → calories updates to `25×4 + 30×4 + 10×9 = 310`
3. Manually change calories to 300 → auto-compute stops; protein/carbs/fat edits do **not** overwrite 300
4. Clear all three macros → re-enter → auto-compute resumes
5. Save with auto-computed value → food is stored correctly (source='manual')
6. Existing validation rules (non-negative, required) still apply to all four fields

---

## Testing

### Widget test

```dart
testWidgets('calories auto-compute from macros', (tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(createInMemoryDb())],
    child: const MaterialApp(home: ManualFoodForm()),
  ));
  await tester.pumpAndSettle();

  // Enter macros
  await tester.enterText(find.byType(TextFormField).at(1), '1'); // qty
  await tester.enterText(find.byType(TextFormField).at(3), '20'); // protein
  await tester.enterText(find.byType(TextFormField).at(4), '30'); // carbs
  await tester.enterText(find.byType(TextFormField).at(5), '10'); // fat

  // Calories field should auto-fill to 290
  expect(find.byType(TextFormField).at(2).widget, isA<TextFormField>());
  // Read controller value:
  // caloriesController.text == '290'
});

testWidgets('manual calories override is respected', (tester) async {
  // Enter protein=20, carbs=30, fat=10 → calories auto-fills to 290
  // Edit calories to 300
  // Change protein to 25
  // Calories should still be 300 (not updated to 310)
});

testWidgets('auto-compute resumes after clearing macros', (tester) async {
  // Enter macros → calories auto-fills
  // Manually edit calories → auto-compute stops
  // Clear all three macros to zero
  // Re-enter macros → calories auto-fills again
});
```

---

## Files touched

| File | Change |
|------|--------|
| `lib/features/logging/widgets/manual_food_form.dart` | Add `_caloriesManuallyEdited` flag, `onChanged` listeners on protein/carbs/fat, auto-compute logic |
