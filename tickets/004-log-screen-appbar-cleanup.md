# 004 — Log screen AppBar cleanup

**Issues**: #6, #10, #11
**Files**: `lib/features/logging/combined_log_screen.dart`
**Effort**: Small

---

## Context

Three independent changes to the log screen's AppBar and entry list, bundled because they all touch the same file.

### #6 — Day navigator not centered

The `DayNavigator` is the AppBar's `title` widget. In Material's AppBar, the title is centered between the leading widget and the actions. Since there's no leading widget and there's a `PopupMenuButton` on the right, the title appears shifted left of screen center.

Current layout:
```
┌─────────────────────────────────────┐
│ ◀ Apr 15 ▶                      ⋮  │  ← title area center = (width - actions) / 2
└─────────────────────────────────────┘
```

Expected:
```
┌─────────────────────────────────────┐
│      ◀ Apr 15 ▶                 ⋮  │  ← title area center = width / 2
└─────────────────────────────────────┘
```

### #10 — Remove relog button

Each food entry currently has an `Icons.replay` duplicate button that opens `QuickFoodLogSheet` pre-filled. This is redundant since the user can tap `+` and see the food in recent foods. Removing it reduces visual clutter.

### #11 — Log recipe as own button

"Log recipe" is buried in the overflow menu's dropdown. It should be a dedicated icon button in the AppBar for quicker access.

---

## Acceptance criteria

### #6
1. The `DayNavigator` (date picker with chevrons) is visually centered in the AppBar
2. The overflow menu (`⋮`) remains on the right side

### #10
1. The `Icons.replay` duplicate button is removed from all food entries
2. The `_onDuplicate` method is removed
3. All other entry interactions (edit, delete, swipe-to-dismiss) still work

### #11
1. An `Icons.menu_book` button appears in the AppBar's action area
2. Tapping the button navigates to `RecipeListScreen` in picker mode (same as current `_onLogRecipe`)
3. The "Log recipe" item is removed from the `PopupMenuButton` overflow menu
4. The overflow menu `PopupMenuButton` (with the remaining share/save items) continues to work

---

## Implementation notes

### Fix for #6
Add `centerTitle: true` to the `AppBar` in `CombinedLogScreen.build()` (line 220).

### Fix for #10
Remove from the `ListView` builder (lines 370-374):
```dart
if (entry.foodId != null)
  IconButton(
    icon: const Icon(Icons.replay, size: 20),
    tooltip: 'Duplicate entry',
    onPressed: () => _onDuplicate(entry),
  ),
```
Remove the `_onDuplicate` method (lines 87-102).
Check that `databaseProvider` and `foodSearchProvider` are still imported (used by other methods).

### Fix for #11
Add before the `PopupMenuButton` in `actions`:
```dart
IconButton(
  icon: const Icon(Icons.menu_book),
  tooltip: 'Log recipe',
  onPressed: _onLogRecipe,
),
```
Remove the `'log_recipe'` case and its `PopupMenuItem` from the overflow menu's `onSelected` and `itemBuilder`.

---

## Testing

1. Open the log screen → verify the date is visually centered
2. Tap left/right chevrons → verify they still navigate days
3. Verify no `Icons.replay` buttons appear on any entry
4. Tap an entry → verify the edit sheet still opens
5. Swipe-to-delete an entry → verify deletion works
6. Tap the new recipe book icon → verify RecipeListScreen opens in picker mode
7. Tap the overflow menu → verify "Log recipe" is gone, share/save are still present
8. Run `flutter analyze` — zero issues
