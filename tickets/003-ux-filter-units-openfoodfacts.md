# Ticket #3: [UX] Filter unit dropdown for OpenFoodFacts imports

**Priority:** 🟢 Medium  
**Effort:** Small-Medium (3-4 hours)  
**Status:** Pending  
**Assignee:** Unassigned  
**Created:** May 16, 2026  
**Tags:** `ux`, `openfoodfacts`, `import`, `units`

---

## Problem Statement

When importing foods from OpenFoodFacts, the unit dropdown shows all 11 common units even though the food's macros are defined per a specific unit (e.g., per 100g). This confuses users into thinking they can convert units when they're only changing the label.

**User Impact:** Users may select an inappropriate unit (e.g., "cups" for a food defined per 100g), leading to confusion about serving sizes and macro calculations.

### Example

OpenFoodFacts returns:
```json
{
  "product_name": "Oats",
  "serving_size": "100g",
  "nutriments": {
    "energy-kcal_serving": 389,
    "proteins_serving": 16.9,
    // ... per 100g values
  }
}
```

**Current behavior:**
- Dropdown shows: `g`, `ml`, `fl oz`, `oz`, `cups`, `tbsp`, `tsp`, `slices`, `pieces`, `bars`, `servings`, `Custom…`
- User might select "cups" → entry shows "100 cups" (nonsensical)

**Desired behavior:**
- Dropdown shows: `g`, `Custom…` (only the parsed unit + custom option)
- User can still override if API parsing was wrong

---

## Current Implementation

### Unit Parsing (Works Correctly)

**File:** `lib/core/api/models/food_result.dart:92-171`

```dart
static ({double quantity, String unit}) parseServingInfo(String label) {
  // Parses "100g" → (quantity: 100, unit: 'g')
  // Parses "1 cup (240ml)" → (quantity: 240, unit: 'ml')
  // Parses "2.5 oz" → (quantity: 71, unit: 'g') (converted)
  // ...
}
```

### Unit Dropdown (Problem Area)

**File:** `lib/features/logging/widgets/serving_size_picker.dart:3-6, 149-159`

```dart
const _commonUnits = [
  'g', 'ml', 'fl oz', 'oz', 'cups', 'tbsp', 'tsp',
  'slices', 'pieces', 'bars', 'servings',  // ← Always shows all 11
];

// Dropdown items:
items: [
  ..._commonUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))),
  const DropdownMenuItem(value: '__custom__', child: Text('Custom…')),
],
```

### Quick-Log Sheet (Default Values)

**File:** `lib/features/logging/widgets/quick_food_log_sheet.dart:28-44`

```dart
@override
void initState() {
  super.initState();
  _servings = widget.food.servingQuantity;  // ✓ Default from API
  _unit = widget.food.servingUnit;          // ✓ Default from API
}
```

---

## Acceptance Criteria

### Functional
- [ ] Imported food (`source == 'open_food_facts'`) → dropdown shows only `[parsedUnit, 'Custom…']`
- [ ] Manual food (`source == 'manual'`) → dropdown shows all 11 common units
- [ ] Custom unit selection works for both imported and manual foods
- [ ] Parsed unit from API is the default selection (unchanged)
- [ ] Unit change affects only the entry's `servingLabel` (not the Food record)

### Edge Cases
- [ ] Barcode scan (also OpenFoodFacts source) → same filtered behavior
- [ ] API parsing fails → fallback to `(1, 'serving')` → dropdown shows `['serving', 'Custom…']`
- [ ] User selects custom unit → can log food with arbitrary unit (e.g., "portions")
- [ ] Duplicate entry (re-log same food) → filtered dropdown based on original food's source

### Non-Functional
- [ ] No console errors when filtering units
- [ ] Dropdown animation smooth (no layout shifts)
- [ ] Backward compatible: manual foods unchanged

---

## Technical Implementation

### Files to Modify

1. **`lib/features/logging/widgets/serving_size_picker.dart`**
   - Add `source` parameter to widget
   - Add `_allowedUnits` computed property
   - Filter dropdown items based on source

2. **`lib/features/logging/widgets/quick_food_log_sheet.dart`**
   - Pass `food.source` to `ServingSizePicker`

3. **New test file:** `test/features/logging/widgets/serving_size_picker_test.dart`
   - Test filtered dropdown for imported foods
   - Test full list for manual foods

### Code Changes

#### Change 1: Add `source` parameter to `ServingSizePicker`

**File:** `lib/features/logging/widgets/serving_size_picker.dart:8-20`

**Current:**
```dart
class ServingSizePicker extends StatefulWidget {
  final double quantity;
  final String unit;
  final ValueChanged<double> onQuantityChanged;
  final ValueChanged<String> onUnitChanged;

  const ServingSizePicker({
    super.key,
    required this.quantity,
    required this.unit,
    required this.onQuantityChanged,
    required this.onUnitChanged,
  });
}
```

**Updated:**
```dart
class ServingSizePicker extends StatefulWidget {
  final double quantity;
  final String unit;
  final ValueChanged<double> onQuantityChanged;
  final ValueChanged<String> onUnitChanged;
  final String? source;  // ← New: 'open_food_facts' or null

  const ServingSizePicker({
    super.key,
    required this.quantity,
    required this.unit,
    required this.onQuantityChanged,
    required this.onUnitChanged,
    this.source,  // ← New parameter
  });
}
```

#### Change 2: Add filtered units logic

**File:** `lib/features/logging/widgets/serving_size_picker.dart:56-59`

**Add after line 56:**
```dart
String get _effectiveUnit => _customUnit ?? widget.unit;

bool get _unitIsCommon => _allowedUnits.contains(_effectiveUnit);

List<String> get _allowedUnits {
  // Filter units for imported foods to prevent confusion
  if (widget.source == 'open_food_facts') {
    return [widget.unit, '__custom__'];  // Only parsed unit + custom
  }
  return _commonUnits;  // All units for manual foods
}
```

#### Change 3: Update dropdown items

**File:** `lib/features/logging/widgets/serving_size_picker.dart:149-159`

**Current:**
```dart
items: [
  ..._commonUnits.map((u) => DropdownMenuItem(
        value: u,
        child: Text(u),
      )),
  const DropdownMenuItem(
    value: '__custom__',
    child: Text('Custom…'),
  ),
],
```

**Updated:**
```dart
items: [
  ..._allowedUnits.map((u) => DropdownMenuItem(
        value: u,
        child: Text(u),
      )),
],
```

Note: `__custom__` is now included in `_allowedUnits` for imported foods.

#### Change 4: Pass source from `QuickFoodLogSheet`

**File:** `lib/features/logging/widgets/quick_food_log_sheet.dart`

**Find:** `ServingSizePicker` instantiation (around line 157-162)

**Current:**
```dart
ServingSizePicker(
  quantity: _servings,
  unit: _unit,
  onQuantityChanged: (v) => setState(() => _servings = v),
  onUnitChanged: (v) => setState(() => _unit = v),
),
```

**Updated:**
```dart
ServingSizePicker(
  quantity: _servings,
  unit: _unit,
  source: widget.food.source,  // ← Pass source
  onQuantityChanged: (v) => setState(() => _servings = v),
  onUnitChanged: (v) => setState(() => _unit = v),
),
```

---

## Testing Plan

### Unit Tests (New file: `test/features/logging/widgets/serving_size_picker_test.dart`)

**Test 1: Imported food shows filtered units**
```dart
testWidgets('imported food shows filtered dropdown', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ServingSizePicker(
          quantity: 100,
          unit: 'g',
          source: 'open_food_facts',
          onQuantityChanged: (_) {},
          onUnitChanged: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Tap dropdown
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();

  // Should show only 'g' and 'Custom…'
  expect(find.text('g'), findsOneWidget);
  expect(find.text('Custom…'), findsOneWidget);
  
  // Should NOT show other units
  expect(find.text('ml'), findsNothing);
  expect(find.text('cups'), findsNothing);
  expect(find.text('oz'), findsNothing);
});
```

**Test 2: Manual food shows all units**
```dart
testWidgets('manual food shows all units', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ServingSizePicker(
          quantity: 1,
          unit: 'serving',
          source: 'manual',
          onQuantityChanged: (_) {},
          onUnitChanged: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Tap dropdown
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();

  // Should show all common units
  expect(find.text('g'), findsOneWidget);
  expect(find.text('ml'), findsOneWidget);
  expect(find.text('cups'), findsOneWidget);
  expect(find.text('tbsp'), findsOneWidget);
  expect(find.text('tsp'), findsOneWidget);
  expect(find.text('Custom…'), findsOneWidget);
});
```

**Test 3: Custom unit selection works**
```dart
testWidgets('custom unit selection works for imported food', (tester) async {
  String? selectedUnit;
  
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ServingSizePicker(
          quantity: 100,
          unit: 'g',
          source: 'open_food_facts',
          onQuantityChanged: (_) {},
          onUnitChanged: (v) => selectedUnit = v,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Tap dropdown
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();

  // Tap 'Custom…'
  await tester.tap(find.text('Custom…'));
  await tester.pumpAndSettle();

  // Enter custom unit
  await tester.enterText(find.byType(TextField), 'portions');
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  expect(selectedUnit, 'portions');
});
```

**Test 4: Null source defaults to all units (backward compatibility)**
```dart
testWidgets('null source defaults to all units', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ServingSizePicker(
          quantity: 1,
          unit: 'serving',
          source: null,  // Explicitly null
          onQuantityChanged: (_) {},
          onUnitChanged: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Tap dropdown
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();

  // Should show all units (backward compatible)
  expect(find.text('g'), findsOneWidget);
  expect(find.text('ml'), findsOneWidget);
});
```

### Manual Testing Checklist

1. **OpenFoodFacts import flow**
   - [ ] Search for "oats" in web search
   - [ ] Tap imported food → quick-log sheet opens
   - [ ] Verify dropdown shows only `['g', 'Custom…']` (or parsed unit)
   - [ ] Verify default quantity/unit match API values
   - [ ] Select custom unit → log entry → verify entry shows custom unit

2. **Manual food flow (regression)**
   - [ ] Create custom food manually
   - [ ] Log food → quick-log sheet opens
   - [ ] Verify dropdown shows all 11 common units
   - [ ] Change unit → log entry → verify entry shows selected unit

3. **Barcode scan flow**
   - [ ] Scan barcode (if available)
   - [ ] Verify same filtered behavior as OpenFoodFacts import

4. **Edge cases**
   - [ ] Import food with unusual unit (e.g., "ml") → dropdown shows `['ml', 'Custom…']`
   - [ ] Import food with failed parsing → dropdown shows `['serving', 'Custom…']`
   - [ ] Re-log same food (duplicate) → filtered based on original source

---

## Definition of Done

- [ ] Code changes implemented (3 files modified)
- [ ] Unit tests added and passing (4 new tests)
- [ ] Manual testing checklist complete
- [ ] No regressions in existing food log tests (`flutter test test/features/logging/`)
- [ ] `flutter analyze` passes with zero issues
- [ ] Backward compatibility verified (manual foods unchanged)

---

## Dependencies

- None (UI change, no data model changes)

---

## References

- Discovery report: `DISCOVERY.md` (Issue #5 section)
- Related files:
  - `lib/features/logging/widgets/serving_size_picker.dart`
  - `lib/features/logging/widgets/quick_food_log_sheet.dart`
  - `lib/core/api/models/food_result.dart:92-171`

---

## Design Decision Notes

### Why Filter Instead of Read-Only?

**Option A (chosen):** Filter to `[parsedUnit, 'Custom…']`
- Pros: Prevents confusion, allows override if API parsing wrong
- Cons: User can't easily switch between common units (e.g., 'g' ↔ 'oz')

**Option B:** Make unit read-only for imported foods
- Rejected: Too restrictive, API parsing can be wrong

**Option C:** Keep current behavior, add explanation tooltip
- Rejected: Doesn't prevent confusion, just explains it

### Future Enhancement

Consider adding unit conversion (not just label change):
- User selects "oz" → convert macros from per-100g to per-oz
- Requires: macro recalculation on unit change
- Out of scope for this ticket

---

## Notes

**Source Tracking:**
- Currently `FoodSearchItem` has `source` field from API parsing
- Manual foods have `source: 'manual'`
- This field is already used in `quick_food_log_sheet.dart:57` to decide whether to insert Food

**Backward Compatibility:**
- `source` parameter is optional (`String?`)
- Null source defaults to all units (existing behavior)
- No breaking changes to existing code
