# Discovery Report: Issues #1-5

**Date:** May 16, 2026  
**Author:** opencode  
**Project:** bioloop — Flutter macro counter

---

## Executive Summary

| Issue | Status | Root Cause | Effort |
|-------|--------|------------|--------|
| #1 Recipe editing | ✅ Already implemented | UX confusion — edit icon not obvious | Low (UX improvement) |
| #2 Recipe macros zeroes | 🔴 **Confirmed bug** | `recipeId` not passed when logging from edit screen | Medium |
| #3 Long-press delete | ✅ Already implemented | May not be discoverable | Low (UX improvement) |
| #4 Pre-weight assumption | 🟡 Not implemented | Algorithm excludes dates before first weight | Medium |
| #5 OpenFoodFacts units | 🟡 Not implemented | Unit dropdown shows all 11 common units instead of filtered list | Low-Medium |

---

## Issue #1: Recipe Editing Navigation

### Problem Statement
> "the user should be able to edit recipes. currently when the user taps a recipe, it just goes straight into logging that recipe"

### Current Implementation

**File:** `lib/features/recipes/recipe_list_screen.dart`

The recipe list screen has **two modes**:

1. **Management mode** (`pickerMode: false`) — accessed from Recipes tab
   - Tap edit icon (✏️) → `RecipeFormScreen(recipeId: recipe.id)` (lines 116-120)
   - Tap card → same as edit icon (line 89 → `_openRecipe`)
   - Long press → delete confirmation (line 219)
   - Delete icon (🗑️) → delete confirmation (lines 206-212)
   - Duplicate icon (📋) → duplicate then edit (lines 153-168)

2. **Picker mode** (`pickerMode: true`) — accessed from Log screen "Log recipe" button
   - Tap card → `LogRecipeSheet` modal (lines 105-113)
   - No edit/duplicate/delete icons shown (lines 197-198)

### Key Finding

**Recipe editing IS implemented** at `recipe_list_screen.dart:116-120`. The issue is likely:

1. **UX confusion**: Users accessing recipes from the Log screen (picker mode) cannot edit — they can only log
2. **Icon discoverability**: The edit icon (✏️) may not be obvious enough in the recipe card trailing

### Code Reference

```dart
// lib/features/recipes/recipe_list_screen.dart:100-120
Future<void> _openRecipe(
    BuildContext context, WidgetRef ref, Recipe recipe) async {
  if (pickerMode) {
    // Picker mode: go straight to logging
    final detail = await ref.read(recipeDetailProvider(recipe.id).future);
    // ... opens LogRecipeSheet
  } else {
    // Management mode: navigate to edit form
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeFormScreen(recipeId: recipe.id), // ← EDIT MODE
      ),
    );
  }
}
```

### Recommendation

1. **Clarify the two flows**: The Recipes tab is for management (create/edit/delete), the Log screen picker is for logging only
2. **Improve edit icon visibility**: Consider making the entire card tappable for edit in management mode, with a separate "Log" button
3. **Add tooltip**: The edit icon already has `tooltip: 'Edit recipe'` (line 204) — ensure it's visible on long-press

---

## Issue #2: Recipe Macros Showing Zeroes

### Problem Statement
> "currently logging recipes is broken - calculated macros are all zeroes every time"

### Root Cause Analysis

**File:** `lib/core/database/database.dart:353-391` (`computeRecipeMacros`)

The macro calculation formula is **correct**:
```dart
for (final item in ingredients) {
  final qty = item.ingredient.quantity;
  final sq = item.food.servingQuantity > 0 ? item.food.servingQuantity : 1;
  totalCals += item.food.caloriesPerServing * (qty / sq);  // ← Correct formula
  // ... protein, carbs, fat
}
```

**Tests confirm the formula works** (`test/features/recipes/recipes_test.dart:140-168`):
```dart
test('compute macros single ingredient', () async {
  // Chicken Breast: 165 cal, 31g protein per serving (servingQuantity=1)
  // Ingredient quantity: 2 servings
  // Expected: 165 * (2/1) = 330 cal ✓
  final macros = await db.computeRecipeMacros(recipeId);
  expect(macros.calories, closeTo(330, 0.01)); // PASSES
});
```

### Potential Zero Sources

| Source | Location | Condition | Likelihood |
|--------|----------|-----------|------------|
| Recipe not found | `database.dart:355-365` | `getRecipe(recipeId)` returns `null` | Low |
| No ingredients | `database.dart:368` | `getIngredientsWithFood` returns `[]` | **High** |
| Foods have zero macros | `database.dart:371-377` | `caloriesPerServing`, etc. are 0 | Medium |
| Zero `servingQuantity` | `database.dart:373` | Guard prevents division by zero | Low |

### Critical Finding: Logging from Edit Screen

**File:** `lib/features/recipes/recipe_form_screen.dart:261-269`

```dart
void _openLogSheet() {
  final asyncDetail = ref.read(recipeDetailProvider(widget.recipeId!));
  final detail = asyncDetail.asData?.value;
  if (detail == null) return;  // ← If null, silently returns!
  showModalBottomSheet(
    context: context,
    builder: (_) => LogRecipeSheet(detail: detail),
  );
}
```

**Problem:** If `recipeDetailProvider` hasn't loaded yet (async), `detail` is `null` and the function returns silently. The user sees nothing happen.

### Additional Finding: Ingredient Save Logic

**File:** `lib/features/recipes/recipe_form_screen.dart:195-259`

When **creating** a new recipe:
```dart
final recipeId = await db.insertRecipe(RecipesCompanion.insert(...));
for (final item in _ingredients) {
  await db.insertIngredient(RecipeIngredientsCompanion.insert(
    recipeId: recipeId,  // ← Correct: uses new ID
    foodId: item.ingredient.foodId,
    quantity: item.ingredient.quantity,
    createdAt: now,
  ));
}
```

When **updating** an existing recipe:
```dart
if (widget.recipeId != null) {
  await db.updateRecipe(widget.recipeId!, RecipesCompanion(...));
  await db.deleteIngredientsForRecipe(widget.recipeId!);  // ← Deletes all
  // ⚠️ BUT: No re-insert of ingredients!
}
```

### 🔴 **CONFIRMED BUG**: Update Path Missing Ingredient Re-Insert

**Location:** `lib/features/recipes/recipe_form_screen.dart:204-217`

When editing an existing recipe:
1. Recipe row is updated ✓
2. All ingredients are deleted ✓
3. **Ingredients are NOT re-inserted** ✗

This means **after editing any recipe, all ingredients are lost**, resulting in:
- `computeRecipeMacros()` returns all zeroes (no ingredients)
- `logRecipe()` logs zeroes (macros are zero)

### Fix Required

```dart
// After line 212 (after deleteIngredientsForRecipe)
for (final item in _ingredients) {
  await db.insertIngredient(RecipeIngredientsCompanion.insert(
    recipeId: widget.recipeId!,  // ← Re-insert ingredients
    foodId: item.ingredient.foodId,
    quantity: item.ingredient.quantity,
    createdAt: now,
  ));
}
```

### Test Coverage Gap

Existing tests (`recipes_test.dart`) test:
- Creating recipes with ingredients ✓
- Computing macros for recipes with ingredients ✓
- **NOT testing**: Edit → save → compute macros

---

## Issue #3: Long-Press Delete for Recipes

### Problem Statement
> "the user should be able to long press recipes to delete them"

### Current Implementation

**File:** `lib/features/recipes/recipe_list_screen.dart:219`

```dart
class _RecipeCard extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Card(
      // ...
      child: ListTile(
        // ...
        onLongPress: pickerMode ? null : onDelete,  // ← Already implemented!
      ),
    );
  }
}
```

**Delete dialog:** Lines 127-151
```dart
Future<void> _deleteRecipe(...) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete recipe?'),
      content: Text('Delete "${recipe.name}" and all its ingredients?'),
      actions: [/* Cancel, Delete */],
    ),
  );
  if (confirmed == true) {
    await db.deleteIngredientsForRecipe(recipe.id);
    await db.deleteRecipe(recipe.id);
    ref.invalidate(recipeListProvider);
  }
}
```

### Key Finding

**Long-press delete IS implemented** at `recipe_list_screen.dart:219`. The issue is likely:

1. **Discoverability**: No visual cue that long-press is available
2. **Haptic feedback**: No haptic feedback on long-press
3. **Mode confusion**: Only works in management mode (`pickerMode: false`), not in picker mode

### Test Coverage

**File:** `test/features/recipes/recipes_test.dart:595-615`

```dart
testWidgets('delete recipe removes from list', (tester) async {
  // ...
  await tester.tap(find.byIcon(Icons.delete_outline));  // Tests delete ICON
  // ...
  expect(find.text('To Delete'), findsNothing);
});
```

**Gap:** No test for long-press gesture

### Recommendation

1. Add visual cue (e.g., tooltip on card: "Long-press to delete")
2. Add haptic feedback on long-press
3. Add test for long-press gesture
4. Consider showing delete icon only on long-press (swipe-to-dismiss pattern)

---

## Issue #4: Maintenance Regression — Pre-Onboarding Weight Assumption

### Problem Statement
> "when calculating maintenance calories using our regression algorithm, we're already assuming no weight change on days where the user didn't log a weight. similarly, we should assume the same weight as oldest logged weight for all dates BEFORE that weight."

### Current Algorithm

**File:** `lib/core/algorithms/maintenance_calculator.dart:50-78`

```dart
// Forward-fill: ensure every day has a weight entry
final dateMap = <String, double>{};
for (final w in recentWeights) {
  final date = w.loggedAt.substring(0, 10);
  dateMap[date] = w.weightKg;
}

final start = DateTime.parse(cutoffStr);
final end = today;
final filledWeights = <BodyweightEntry>[];
double? lastKnownWeight;
for (int d = 0; d <= end.difference(start).inDays; d++) {
  final date = start.add(Duration(days: d));
  final dateStr = /* formatted */;
  if (dateMap.containsKey(dateStr)) {
    lastKnownWeight = dateMap[dateStr]!;  // Update on actual weight day
  }
  if (lastKnownWeight != null) {  // ← KEY: Only adds if weight exists
    filledWeights.add(BodyweightEntry(
      id: -1,
      weightKg: lastKnownWeight,
      loggedAt: dateStr,
    ));
  }
}
```

### Current Behavior

| Scenario | Behavior |
|----------|----------|
| Date has actual weight entry | Uses actual weight ✓ |
| Date between first and last weight (no entry) | Forward-fills with last known weight ✓ |
| **Date before first weight entry** | **Excluded entirely** ✗ |
| Date after last weight entry (up to yesterday) | Forward-fills with last known weight ✓ |

### Example from Issue

> "if i onboard today (may 16 2026) at 190lb, it should assume that i was 190lb on all dates prior to may 16."

**Current behavior:**
- 30-day window: April 16 - May 15
- User onboards May 16 with 190lb
- Only May 16 has weight data
- `recentWeights.length < 7` → returns `null` (line 77)
- **No maintenance estimate**

**Desired behavior:**
- Assume 190lb for April 16 - May 15
- 30 days of weight data (all 190lb)
- `recentWeights.length = 30` → passes minimum check
- Maintenance estimate calculated (though with zero weight change, may still return null)

### Required Change

**File:** `lib/core/algorithms/maintenance_calculator.dart:57-78`

**Current:**
```dart
final start = DateTime.parse(cutoffStr);
final end = today;
final filledWeights = <BodyweightEntry>[];
double? lastKnownWeight;
for (int d = 0; d <= end.difference(start).inDays; d++) {
  // ...
  if (dateMap.containsKey(dateStr)) {
    lastKnownWeight = dateMap[dateStr]!;
  }
  if (lastKnownWeight != null) {
    filledWeights.add(/* ... */);
  }
}
```

**Proposed:**
```dart
final start = DateTime.parse(cutoffStr);
final end = today;
final filledWeights = <BodyweightEntry>[];

// Find the oldest known weight
final oldestWeight = recentWeights.isNotEmpty ? recentWeights.first.weightKg : null;

double? lastKnownWeight = oldestWeight;  // ← Initialize to oldest weight
for (int d = 0; d <= end.difference(start).inDays; d++) {
  final date = start.add(Duration(days: d));
  final dateStr = /* formatted */;
  if (dateMap.containsKey(dateStr)) {
    lastKnownWeight = dateMap[dateStr]!;  // Update on actual weight day
  }
  if (lastKnownWeight != null) {  // Now all dates will be included
    filledWeights.add(BodyweightEntry(
      id: -1,
      weightKg: lastKnownWeight,
      loggedAt: dateStr,
    ));
  }
}
```

### Edge Cases to Consider

1. **Single weight entry** (onboarding scenario):
   - All 30 days use that weight
   - Weight slope = 0 (no change)
   - May still return `null` if no variance (line 158: `rSlope.abs() < 1e-10`)

2. **Delete oldest weight**:
   - New oldest weight becomes the assumption for all prior dates
   - Example: Had weights on May 1 (190lb) and May 2 (188lb)
   - Delete May 1 → May 2 becomes oldest (188lb)
   - April 16 - May 1 all assume 188lb

3. **No weight entries**:
   - `oldestWeight = null`
   - Loop never adds entries (line 68 condition fails)
   - `recentWeights.length < 7` → returns `null` ✓

### Test Coverage Needed

**File:** `test/core/algorithms/maintenance_calculator_test.dart`

**Missing tests:**
1. Single weight entry → all 30 days use that weight
2. Delete oldest weight → assumption shifts to new oldest
3. Weight entries starting mid-window → prior dates use oldest weight

### Impact on Regression Accuracy

**Pros:**
- More data points for regression (may pass 7-point minimum)
- Better handles new users with sparse early data

**Cons:**
- Assumes static weight before first entry (may not be true)
- Could smooth out actual weight trends if user had rapid early changes
- May produce false confidence in maintenance estimate

---

## Issue #5: OpenFoodFacts Import — Honor API Units

### Problem Statement
> "when importing a food from openfoodfacts, we should honor the units that it comes in. currently we're allowing the user to pick from our whole default list. it doesn't make much sense for them to be seeing the whole default units list."

### Current Flow

**1. API Parsing** (`lib/core/api/models/food_result.dart:48-68`)
```dart
if (hasServingFields) {
  servingLabel = rawServingSize ?? '100g';
  if (rawServingSize != null) {
    final parsed = parseServingInfo(rawServingSize);  // Extracts unit
    servingQuantity = parsed.quantity;
    servingUnit = parsed.unit;  // ← Parsed from API
  }
}
```

**2. Unit Parsing Logic** (`food_result.dart:92-171`)

The `parseServingInfo()` method uses regex to extract units from strings like:
- `"100g"` → `(quantity: 100, unit: 'g')`
- `"1 cup (240ml)"` → `(quantity: 240, unit: 'ml')`
- `"2.5 oz"` → `(quantity: 71, unit: 'g')` (converted)
- `"1 serving"` → `(quantity: 1, unit: 'serving')` (fallback)

**3. Quick-Log Sheet** (`lib/features/logging/widgets/quick_food_log_sheet.dart:28-44`)
```dart
@override
void initState() {
  super.initState();
  _servings = widget.food.servingQuantity;  // Default from API
  _unit = widget.food.servingUnit;          // Default from API
}
```

**4. Unit Dropdown** (`lib/features/logging/widgets/serving_size_picker.dart:3-6, 138-160`)
```dart
const _commonUnits = [
  'g', 'ml', 'fl oz', 'oz', 'cups', 'tbsp', 'tsp',
  'slices', 'pieces', 'bars', 'servings',  // ← 11 common units
];

// Dropdown shows ALL units:
DropdownButton<String>(
  value: _unitIsCommon ? displayUnit : null,
  items: [
    ..._commonUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))),
    const DropdownMenuItem(value: '__custom__', child: Text('Custom…')),
  ],
)
```

### Current Behavior

When importing from OpenFoodFacts:
1. API returns `serving_size: "100g"` → parsed as `(quantity: 100, unit: 'g')`
2. Quick-log sheet shows default: `100` in quantity, `g` in unit dropdown
3. **User can change unit to ANY of the 11 common units** (or custom)
4. User's unit selection only affects that entry's `servingLabel` (not the Food record)

### Issue

The user sees all 11 common units even though the API specified a specific unit (e.g., 'g'). This is confusing because:
- The food's macros are defined **per 100g**, not per cup/tbsp/etc.
- Changing the unit doesn't convert the macros — it just changes the label
- User might think they're converting units (like 100g → 3.5oz) but they're not

### Design Options

#### Option A: Filter Dropdown to `[parsedUnit, 'Custom…']`

**Implementation:**
```dart
// serving_size_picker.dart
final allowedUnits = widget.source == 'open_food_facts'
    ? [widget.unit, '__custom__']  // Only parsed unit + custom
    : _commonUnits;                // All units for manual foods
```

**Pros:**
- Prevents user from selecting nonsensical units
- Makes it clear the unit is tied to the food's macro definition

**Cons:**
- User can't easily switch between 'g' and 'oz' (both common for imported foods)
- Requires tracking food source in the widget

#### Option B: Make Unit Read-Only for Imported Foods

**Implementation:**
```dart
// quick_food_log_sheet.dart
ServingSizePicker(
  quantity: _servings,
  unit: _unit,
  onQuantityChanged: (v) => setState(() => _servings = v),
  onUnitChanged: widget.food.source == 'open_food_facts'
      ? null  // Disabled
      : (v) => setState(() => _unit = v),
)
```

**Pros:**
- clearest: unit is part of the food definition
- Prevents accidental unit changes

**Cons:**
- User can't correct wrong API parsing (e.g., API says "ml" but should be "g")
- Less flexible

#### Option C: Keep Current Behavior but Add Explanation

**Implementation:**
- Add tooltip: "Unit is from OpenFoodFacts. Changing this only affects the label, not the macro calculation."
- Or add helper text below dropdown

**Pros:**
- Maintains flexibility
- Educates user

**Cons:**
- Doesn't prevent confusion, just explains it

### Recommendation

**Option A (filtered dropdown)** is the best balance:
- Shows parsed unit as default (already happens)
- Allows custom unit if API parsing was wrong
- Prevents nonsensical unit selections
- Can be overridden by tapping "Custom…"

### Implementation Plan

**File:** `lib/features/logging/widgets/serving_size_picker.dart`

1. Add `source` parameter to widget:
```dart
class ServingSizePicker extends StatefulWidget {
  final double quantity;
  final String unit;
  final String? source;  // ← New: 'open_food_facts' or null
  // ...
}
```

2. Filter units based on source:
```dart
List<String> get _allowedUnits {
  if (widget.source == 'open_food_facts') {
    return [widget.unit, '__custom__'];  // Only parsed unit + custom
  }
  return _commonUnits;
}
```

3. Update `QuickFoodLogSheet` to pass source:
```dart
ServingSizePicker(
  quantity: _servings,
  unit: _unit,
  source: widget.food.source,  // ← Pass source
  // ...
)
```

### Test Coverage Needed

1. Imported food with 'g' unit → dropdown shows only ['g', 'Custom…']
2. Imported food with 'ml' unit → dropdown shows only ['ml', 'Custom…']
3. Manual food → dropdown shows all 11 common units
4. Custom unit selection works for both imported and manual foods

---

## Summary of Required Changes

### Issue #1: Recipe Editing (UX Improvement)
- **File:** `lib/features/recipes/recipe_list_screen.dart`
- **Change:** Improve edit icon visibility or add tooltip
- **Effort:** Low

### Issue #2: Recipe Macros Zeroes (Bug Fix) 🔴
- **File:** `lib/features/recipes/recipe_form_screen.dart:204-217`
- **Change:** Re-insert ingredients after deleting them in update path
- **Effort:** Medium
- **Test:** Add test for edit → save → verify macros

### Issue #3: Long-Press Delete (UX Improvement)
- **File:** `lib/features/recipes/recipe_list_screen.dart`
- **Change:** Add haptic feedback, visual cue, test for long-press
- **Effort:** Low

### Issue #4: Pre-Weight Assumption (Algorithm Change)
- **File:** `lib/core/algorithms/maintenance_calculator.dart:57-78`
- **Change:** Initialize `lastKnownWeight` to oldest weight
- **Effort:** Medium
- **Test:** Add tests for single-weight, delete-oldest scenarios

### Issue #5: OpenFoodFacts Units (UX Improvement)
- **Files:** 
  - `lib/features/logging/widgets/serving_size_picker.dart`
  - `lib/features/logging/widgets/quick_food_log_sheet.dart`
- **Change:** Filter dropdown to `[parsedUnit, 'Custom…']` for imported foods
- **Effort:** Low-Medium
- **Test:** Add tests for filtered dropdown

---

## Test Coverage Gaps

### Recipe Tests (`test/features/recipes/recipes_test.dart`)
- [ ] Edit recipe → save → verify ingredients persist
- [ ] Edit recipe → save → verify macros are correct
- [ ] Long-press gesture to delete

### Maintenance Tests (`test/core/algorithms/maintenance_calculator_test.dart`)
- [ ] Single weight entry → all 30 days use that weight
- [ ] Delete oldest weight → assumption shifts to new oldest
- [ ] Weight entries starting mid-window → prior dates use oldest weight

### Unit Tests (new file needed)
- [ ] Imported food dropdown shows filtered units
- [ ] Manual food dropdown shows all units
- [ ] Custom unit selection works for both

---

## Risk Assessment

| Change | Risk | Mitigation |
|--------|------|------------|
| #2 Recipe ingredient re-insert | Medium | Add comprehensive test, manual testing |
| #4 Pre-weight assumption | Medium | May affect existing users' maintenance estimates — document behavior change |
| #5 Unit filtering | Low | Allows custom unit override, minimal breaking change |

---

## Recommended Implementation Order

1. **#2 Recipe macros zeroes** (bug fix, highest priority)
2. **#4 Pre-weight assumption** (algorithm improvement)
3. **#5 OpenFoodFacts units** (UX improvement)
4. **#1 & #3 Recipe UX** (discoverability improvements, lowest priority)
