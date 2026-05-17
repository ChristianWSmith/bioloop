# Ticket 001: Remove duplicate "add new" button from recipe screen

**Issue:** #2 from issues.txt
**Size:** Trivial (~5 min)
**Dependencies:** None

## Problem

`RecipeListScreen` has two identical "add new" buttons:
1. `IconButton` in `AppBar.actions` (top right) — `recipe_list_screen.dart:24-39`
2. `FloatingActionButton` (bottom center) — `recipe_list_screen.dart:41-55`

Both push `RecipeFormScreen` and invalidate `recipeListProvider` on success. The AppBar button is redundant.

## Acceptance Criteria

- [ ] AppBar no longer has an "add" button in its actions
- [ ] FAB still navigates to `RecipeFormScreen` and refreshes the list on save
- [ ] Empty-state text "Tap + to create one." still makes sense (it does — the FAB has a `+` icon)
- [ ] `flutter analyze` passes with zero new issues
- [ ] All existing tests pass

## Files to Change

| File | Change |
|------|--------|
| `lib/features/recipes/recipe_list_screen.dart` | Remove the `actions: [...]` block from the `AppBar` (lines 24-39) |

## Testing

No new tests needed. No existing tests reference the AppBar add button. Verify manually that the FAB still works.

## Notes

The FAB has `heroTag: 'recipe_add'` which should be kept (avoids hero animation conflicts).
