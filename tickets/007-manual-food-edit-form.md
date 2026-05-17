# Ticket 7: Manual Food Edit Form

**Priority:** Medium  
**Complexity:** Medium  
**Estimated effort:** 40 minutes  
**Files:** `lib/features/logging/widgets/manual_food_form.dart`, `lib/core/database/database.dart`

---

## Description

Modify `ManualFoodForm` to support editing existing foods in addition to creating new ones. The form should pre-fill with existing food data and update the database accordingly.

---

## Context

From `DISCOVERY.md`:

> `ManualFoodForm` currently only supports creating new foods. We need to add an optional `existingFood` parameter that pre-fills the form and changes the save logic to update instead of insert.

**Current behavior:**
- Always creates new food
- All fields start empty or with defaults
- Save calls `db.insertFood()`

**New behavior:**
- If `existingFood` is provided:
  - Pre-fill all form fields with food's current data
  - Save calls `db.upsertFood()` or `db.updateFood()`
  - App bar title changes to "Edit Food"
- If `existingFood` is null:
  - Behaves as before (create mode)

**Key files:**
- `lib/features/logging/widgets/manual_food_form.dart` — form UI
- `lib/core/database/database.dart` — database operations

---

## Acceptance Criteria

- [ ] `ManualFoodForm` accepts optional `Food? existingFood` parameter
- [ ] When editing, all form fields pre-fill with existing food data
- [ ] When editing, quantity and unit fields show current values
- [ ] When editing, app bar title shows "Edit Food" instead of "Custom Food"
- [ ] When editing, save button updates existing food (not create new)
- [ ] When creating, behavior unchanged (all fields empty/default)
- [ ] Database update uses `upsertFood()` or new `updateFood()` method
- [ ] After save, navigator pops with updated `Food` object
- [ ] Code compiles without errors

---

## Implementation

### File 1: `lib/features/logging/widgets/manual_food_form.dart`

**Step 1: Add `existingFood` parameter**

```dart
class ManualFoodForm extends ConsumerStatefulWidget {
  final Food? existingFood;  // NEW

  const ManualFoodForm({super.key, this.existingFood});

  @override
  ConsumerState<ManualFoodForm> createState() => _ManualFoodFormState();
}
```

**Step 2: Update state class to handle pre-filling**

```dart
class _ManualFoodFormState extends ConsumerState<ManualFoodForm> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _selectedUnit = 'g';
  String? _customUnit;

  @override
  void initState() {
    super.initState();
    if (widget.existingFood != null) {
      final food = widget.existingFood!;
      _nameController.text = food.name;
      _qtyController.text = food.servingQuantity.toString();
      _caloriesController.text = food.caloriesPerServing.toString();
      _proteinController.text = food.proteinPerServing.toString();
      _carbsController.text = food.carbsPerServing.toString();
      _fatController.text = food.fatPerServing.toString();
      _selectedUnit = food.servingUnit;
      // Check if unit is custom (not in common units list)
      if (!_commonUnits.contains(food.servingUnit)) {
        _customUnit = food.servingUnit;
      }
    }
  }

  // ... rest of methods ...
```

**Step 3: Update `_save()` method to handle edit vs create**

```dart
Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _saving = true);

  final db = ref.read(databaseProvider);
  final now = DateTime.now().toIso8601String();
  final qty = double.tryParse(_qtyController.text) ?? 1;

  try {
    final servingLabel = _buildLabel();

    if (widget.existingFood != null) {
      // EDIT MODE: Update existing food
      await db.upsertFood(FoodsCompanion(
        id: Value(widget.existingFood!.id),  // Include ID for update
        name: Value(_nameController.text.trim()),
        servingLabel: Value(servingLabel),
        servingQuantity: Value(qty),
        servingUnit: Value(_unit),
        caloriesPerServing: Value(double.parse(_caloriesController.text)),
        proteinPerServing: Value(double.parse(_proteinController.text)),
        carbsPerServing: Value(double.parse(_carbsController.text)),
        fatPerServing: Value(double.parse(_fatController.text)),
        // Keep existing barcode, brand, source, createdAt
        barcode: Value(widget.existingFood!.barcode),
        brand: Value(widget.existingFood!.brand),
        source: Value(widget.existingFood!.source),
        createdAt: Value(widget.existingFood!.createdAt),
      ));

      if (mounted) {
        final food = Food(
          id: widget.existingFood!.id,
          name: _nameController.text.trim(),
          servingLabel: servingLabel,
          servingQuantity: qty,
          servingUnit: _unit,
          caloriesPerServing: double.parse(_caloriesController.text),
          proteinPerServing: double.parse(_proteinController.text),
          carbsPerServing: double.parse(_carbsController.text),
          fatPerServing: double.parse(_fatController.text),
          barcode: widget.existingFood!.barcode,
          brand: widget.existingFood!.brand,
          source: widget.existingFood!.source,
          createdAt: widget.existingFood!.createdAt,
        );
        Navigator.of(context).pop(food);
      }
    } else {
      // CREATE MODE: Insert new food (existing logic)
      final id = await db.insertFood(FoodsCompanion.insert(
        name: _nameController.text.trim(),
        servingLabel: servingLabel,
        servingQuantity: Value(qty),
        servingUnit: Value(_unit),
        caloriesPerServing: double.parse(_caloriesController.text),
        proteinPerServing: double.parse(_proteinController.text),
        carbsPerServing: double.parse(_carbsController.text),
        fatPerServing: double.parse(_fatController.text),
        barcode: const Value(null),
        brand: const Value(null),
        source: const Value('manual'),
        createdAt: now,
      ));

      if (mounted) {
        final food = Food(
          id: id,
          name: _nameController.text.trim(),
          servingLabel: servingLabel,
          servingQuantity: qty,
          servingUnit: _unit,
          caloriesPerServing: double.parse(_caloriesController.text),
          proteinPerServing: double.parse(_proteinController.text),
          carbsPerServing: double.parse(_carbsController.text),
          fatPerServing: double.parse(_fatController.text),
          barcode: null,
          brand: null,
          source: 'manual',
          createdAt: now,
        );
        Navigator.of(context).pop(food);
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() => _saving = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to save: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
```

**Step 4: Update app bar title**

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.existingFood != null ? 'Edit Food' : 'Custom Food'),
    ),
    // ... rest of body ...
  );
}
```

### File 2: `lib/core/database/database.dart`

**Review existing `upsertFood()` method (lines 118-128):**

```dart
Future<void> upsertFood(FoodsCompanion food) async {
  final barcode = food.barcode.value;
  if (barcode != null) {
    final existing = await getByBarcode(barcode);
    if (existing != null) {
      await (update(foods)..where((f) => f.barcode.equals(barcode)))
          .write(food);
      return;
    }
  }
  await into(foods).insert(food);
}
```

**Issue:** Current `upsertFood()` only updates by barcode, but manual foods don't have barcodes. We need to add an `updateFoodById()` method or modify the logic.

**Add new method:**

```dart
Future<void> updateFoodById(int id, FoodsCompanion food) async {
  await (update(foods)..where((f) => f.id.equals(id))).write(food);
}
```

**Alternative:** Modify `upsertFood()` to also check for ID in the companion, or create a separate `updateFood()` method that accepts ID and a partial companion.

**Recommended approach:** Add a dedicated `updateFoodById()` method for clarity:

```dart
// Add after upsertFood() (around line 128)
Future<void> updateFoodById(int id, FoodsCompanion food) async {
  await (update(foods)..where((f) => f.id.equals(id))).write(food);
}
```

Then in `ManualFoodForm._save()`, use:

```dart
await db.updateFoodById(widget.existingFood!.id, FoodsCompanion(
  name: Value(_nameController.text.trim()),
  servingLabel: Value(servingLabel),
  servingQuantity: Value(qty),
  servingUnit: Value(_unit),
  caloriesPerServing: Value(double.parse(_caloriesController.text)),
  proteinPerServing: Value(double.parse(_proteinController.text)),
  carbsPerServing: Value(double.parse(_carbsController.text)),
  fatPerServing: Value(double.parse(_fatController.text)),
));
```

**Note:** The `FoodsCompanion` constructor doesn't require all fields when updating — only the fields you want to change need `Value(...)`, others can be omitted or set to `Value.absent()`.

---

## Testing Plan

### Manual Testing

1. **Create mode (existing behavior):**
   - [ ] Open from "Create custom food" → all fields empty/default
   - [ ] Fill in all fields → save → food created
   - [ ] Cancel → form dismissed, no data saved

2. **Edit mode (new behavior):**
   - [ ] Open from edit button → all fields pre-filled
   - [ ] Edit name → save → name updates in database
   - [ ] Edit serving size → save → serving updates
   - [ ] Edit macros → save → macros update
   - [ ] Cancel → changes discarded, original values preserved

3. **Edge cases:**
   - [ ] Edit food with custom unit → unit shows correctly
   - [ ] Edit food with decimal quantity → quantity shows correctly
   - [ ] Edit food, change to custom unit → saves correctly
   - [ ] Edit food, clear a required field → validation error shows

### Verification
- [ ] Run `flutter analyze > analyze.log 2>&1` and read `analyze.log` — zero issues
- [ ] Run `flutter test > test.log 2>&1` and read `test.log` — all tests pass

---

## Dependencies

- **Required by:** Ticket 6 (Food Edit/Delete UI)
- **Dependencies:** None — can be implemented independently

---

## Notes

- `FoodsCompanion` uses `Value<T>` wrapper for drift updates
- When editing, only changed fields need to be in the companion
- `Value.absent()` means "don't update this field"
- `Value(null)` means "set this field to null"
- Form validation should work the same in both modes
- Auto-calc calories feature (4-4-9 rule) should work in edit mode too
- After editing, the updated `Food` object is popped back to caller
- Caller (Ticket 6) is responsible for refreshing the food list
