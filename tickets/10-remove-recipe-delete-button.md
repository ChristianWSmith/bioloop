# Ticket 10: Remove redundant delete button from recipe cards

**Category:** Recipe Management
**Status:** Pending
**Depends on:** None
**Blocks:** None

## Problem

Recipe cards in the management screen have both a delete button (trailing `IconButton`) AND long-press delete with haptic feedback and scale animation. The delete button is redundant.

## Context

- `lib/features/recipes/recipe_list_screen.dart:176-190` — trailing `Row` with edit + delete buttons
- `lib/features/recipes/recipe_list_screen.dart:184-188` — the delete `IconButton` to remove
- `lib/features/recipes/recipe_list_screen.dart:192-199` — long-press handler with `HapticFeedback.mediumImpact()` and `AnimatedScale` (keep this)
- `lib/features/recipes/recipe_list_screen.dart:160-161` — tooltip: `'Tap to log, long-press to delete'` (already correct)

## Changes Required

Remove the delete `IconButton` from `_RecipeCard`'s trailing `Row`:

```dart
// Before (lines 176-190):
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(icon: Icons.edit, ...),
    IconButton(icon: Icons.delete_outline, ...),  // REMOVE THIS
  ],
),

// After:
trailing: IconButton(
  icon: const Icon(Icons.edit, size: 20),
  onPressed: widget.onEdit,
  tooltip: 'Edit recipe',
),
```

Keep:
- The edit `IconButton`
- The `onLongPress` handler with haptic feedback and scale animation
- The `onDelete` callback (still called by long-press)
- The tooltip text (already says "Tap to log, long-press to delete")

## Acceptance Criteria

- [ ] Recipe cards show only the edit button in the trailing area
- [ ] Long-press on a recipe card still triggers delete with haptic feedback and scale animation
- [ ] The `onDelete` callback is still wired and functional (used by long-press)
- [ ] `flutter analyze` passes with zero issues

## Testing

- Widget test: recipe card has edit button but no delete button in trailing area
- Widget test: long-press on recipe card → delete confirmation dialog appears
- Existing recipe tests in `recipes_test.dart` should still pass

## Files Affected

- `lib/features/recipes/recipe_list_screen.dart` — remove delete IconButton from trailing Row
