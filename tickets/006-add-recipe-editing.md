# T6: Add recipe editing

**Issue:** #4
**Effort:** ~10 min
**Dependencies:** None

## Context

`RecipeFormScreen` (`lib/features/recipes/recipe_form_screen.dart`) already supports edit mode — when `recipeId` is non-null, it loads the existing recipe via `recipeDetailProvider(recipeId)`, populates all form fields, and saves via `db.updateRecipe()` + ingredient re-insertion.

However, there is **no way to discover or trigger this edit mode** from the recipe list screen. Tapping a recipe card does **not** open editing — it opens `LogRecipeSheet` (picking a portion to log). The edit flow is completely hidden.

The `_RecipeCard` widget in `recipe_list_screen.dart` has a trailing delete `IconButton` (in non-picker mode) or a chevron (in picker mode), but no edit button. The card's `onTap` opens `LogRecipeSheet`, not the edit form.

## Intent

Add an explicit edit action to recipe cards in non-picker mode so users can access the existing edit form.

## Changes

**File:** `lib/features/recipes/recipe_list_screen.dart`

Option A (simple): Add an edit `IconButton` (pencil icon) to `_RecipeCard.trailing`, alongside the existing delete button, in non-picker mode. On tap, push `RecipeFormScreen(recipeId: recipe.id)`.

Option B (recommended as prep for T7): Replace the trailing widget with a `PopupMenuButton` containing "Edit", "Duplicate" (prep for T7), and "Delete" options. This scales better as more actions are added.

**Option B approach:**

```dart
// In _RecipeCard.build(), non-picker mode:
trailing: PopupMenuButton<String>(
  onSelected: (value) {
    switch (value) {
      case 'edit': onEdit();  // new callback: push RecipeFormScreen(recipeId: id)
      case 'duplicate': onDuplicate();  // T7
      case 'delete': onDelete();  // existing
    }
  },
  itemBuilder: (_) => [
    const PopupMenuItem(value: 'edit', child: Text('Edit')),
    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
    const PopupMenuItem(value: 'delete', child: Text('Delete')),
  ],
),
```

This requires adding an `onEdit` callback to `_RecipeCard` and wiring it through `_openRecipe` or a separate handler. The `PickerMode` cards can keep the chevron + log-on-tap behaviour unchanged.

## Testing

- **Manual:** Open the Recipes tab (not from the log screen picker). Tap the overflow menu on a recipe card. Select "Edit". Verify the form opens pre-populated with the recipe name, serving size, unit, and all ingredients. Change something and save. Verify the list refreshes with the updated data.
- **Widget test:** Create recipes in an in-memory DB. Render `RecipeListScreen(pickerMode: false)` in a `ProviderScope`. Find a recipe card, tap the overflow menu, verify "Edit" option exists and navigates to `RecipeFormScreen` with the correct `recipeId`.
