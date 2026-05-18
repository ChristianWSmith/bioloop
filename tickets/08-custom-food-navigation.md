# Ticket 08: Fix custom food creation navigation

**Category:** Food Search UX
**Status:** Pending
**Depends on:** None
**Blocks:** None

## Problem

When the user taps "Create custom food" in the search delegate, the current flow pops the search delegate BEFORE pushing `ManualFoodForm`. This means if the user backs out of the form without saving, they return to the log screen instead of the search delegate.

**Current flow:**
```
CombinedLogScreen
  └── showSearch(FoodSearchDelegate)
        └── "Create custom food" tapped
              ├── onCreateCustomFood() → sets _pendingCreateCustom = true
              └── Navigator.pop(null) → pops the search delegate
  └── result is null, _pendingCreateCustom is true
        └── _openCreateCustom() → pushes ManualFoodForm
              └── User backs out → returns to CombinedLogScreen (search is gone)
```

**Desired flow:**
```
CombinedLogScreen
  └── showSearch(FoodSearchDelegate)
        └── "Create custom food" tapped
              └── Navigator.push(ManualFoodForm) — stacked on top of delegate
                    └── User saves → pop form, then pop delegate, then quick-log
                    └── User backs out → pop form, return to search delegate
```

This same pattern exists in `RecipeFormScreen._addIngredient()`.

## Context

- `lib/features/logging/combined_log_screen.dart:56-78` — `_onSearch()` with `_pendingCreateCustom` flag pattern
- `lib/features/logging/combined_log_screen.dart:97-107` — `_openCreateCustom()` pushes `ManualFoodForm`
- `lib/features/logging/widgets/food_search_delegate.dart:229-235` — "Create custom food" ListTile calls `onCreateCustomFood()` then `Navigator.pop(null)`
- `lib/features/recipes/recipe_form_screen.dart:66-94` — `_addIngredient()` with same `_pendingCreateCustom` pattern

## Changes Required

### Change `onCreateCustomFood` callback signature

From: `VoidCallback onCreateCustomFood`
To: `Future<Food?> Function(BuildContext) onCreateCustomFood`

### In `_LocalSearchContent` (food_search_delegate.dart)

Replace the "Create custom food" ListTile's `onTap`:
```dart
// Before:
onTap: () {
  onCreateCustomFood();
  Navigator.of(context).pop<FoodSearchItem?>(null);
},

// After:
onTap: () async {
  final food = await onCreateCustomFood(context);
  if (food != null && mounted) {
    // Pop the delegate and return the food for quick-logging
    Navigator.of(context).pop<FoodSearchItem?>(
      FoodSearchItem.fromFood(food),
    );
  }
  // If food is null (user backed out), do nothing — stay in search
},
```

### In `CombinedLogScreen`

Update the callback:
```dart
onCreateCustomFood: (context) async {
  return await Navigator.of(context).push<Food>(
    MaterialPageRoute(builder: (_) => const ManualFoodForm()),
  );
},
```

Remove `_pendingCreateCustom` field and `_openCreateCustom()` method — no longer needed.

### In `RecipeFormScreen`

Same pattern update for `_addIngredient()`.

## Acceptance Criteria

- [ ] From log screen: tap "Create custom food" → form appears on top of search
- [ ] From log screen: back out of form → returns to search delegate (not log screen)
- [ ] From log screen: save food → quick-log sheet opens with the new food
- [ ] From recipe form: tap "Create custom food" → form appears on top of search
- [ ] From recipe form: back out of form → returns to search delegate
- [ ] From recipe form: save food → ingredient is added to the recipe
- [ ] `flutter analyze` passes with zero issues

## Testing

- Widget test: open search → tap "Create custom food" → press back → search delegate is still visible
- Widget test: open search → tap "Create custom food" → fill form → save → quick-log sheet appears
- Widget test: from recipe form → add ingredient → create custom food → save → ingredient appears in list

## Files Affected

- `lib/features/logging/widgets/food_search_delegate.dart` — change callback signature, update onTap handler
- `lib/features/logging/combined_log_screen.dart` — update callback, remove `_pendingCreateCustom` and `_openCreateCustom()`
- `lib/features/recipes/recipe_form_screen.dart` — same pattern update
- `test/features/logging/search_delegate_test.dart` — update tests for new navigation flow
