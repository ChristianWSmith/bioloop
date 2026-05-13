# 008 — Fix recipes screen: missing "+" button and empty state text

- **Phase**: 3 — Bug Fixes
- **Priority**: High

## Overview

The recipes screen is only reachable from the Log screen in "picker mode", which hides the AppBar add button (`Icons.add`). There is no FAB. The empty state says "No recipes yet.\nTap + to create one." but no "+" is visible to tap. Fix the screen so users can create recipes from within the app.

## Context from Discovery

- `RecipeListScreen` (`lib/features/recipes/recipe_list_screen.dart`): accepts `pickerMode` parameter (default `false`).
- AppBar `actions`: `if (!pickerMode) IconButton(... Icons.add ...)`.
- No `FloatingActionButton` anywhere on the screen.
- Only instantiated from `LogFoodScreen` as `const RecipeListScreen(pickerMode: true)`.
- Non-picker mode (`pickerMode: false`) with the "+" is only used in tests.
- Empty state text: `'No recipes yet.\nTap + to create one.'`.

## Options

1. **Add a FAB**: Always show a FAB with `Icons.add` regardless of picker mode. This is the most visible fix.
2. **Show AppBar add button in picker mode**: Remove the `if (!pickerMode)` guard.
3. **Both**: FAB for primary action, AppBar button for discoverability.

Recommendation: Option 1 (FAB) is most consistent with Material 3 patterns for screens with potentially empty content. Also update the empty state text.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/recipes/recipe_list_screen.dart` | Add `FloatingActionButton` with `Icons.add` (visible in all modes). Update empty state text to match the actual UX. |

## Acceptance Criteria

- [ ] A "+" button (FAB) is visible on the recipes screen when it's empty
- [ ] A "+" button (FAB) is visible when recipes exist (always visible)
- [ ] Tapping "+" navigates to `RecipeFormScreen` to create a new recipe
- [ ] Empty state text accurately describes how to add a recipe
- [ ] After creating a recipe, the recipe list refreshes
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Widget test: FAB is present on `RecipeListScreen` with `pickerMode: true`
- Widget test: FAB is present with `pickerMode: false`
- Widget test: tapping FAB navigates to `RecipeFormScreen`
- Widget test: empty state text is updated
