# Ticket 2: Unified Recipe Management Interactions

**Priority:** High  
**Complexity:** Low-Medium  
**Estimated effort:** 45 minutes  
**Files:** `lib/features/recipes/recipe_list_screen.dart`, `lib/features/logging/combined_log_screen.dart`

---

## Description

Remove the `pickerMode` distinction and create a unified recipe list experience where users can log, edit, or delete recipes from any context.

**Current behavior:**
- **Recipes tab (pickerMode: false):** Tap = edit, Long-press = delete, Trailing = edit/duplicate/delete buttons
- **Log screen (pickerMode: true):** Tap = log, Long-press = nothing, Trailing = chevron only

**New unified behavior:**
- **Tap** → Open `LogRecipeSheet` to log the recipe
- **Long-press** → Delete recipe with confirmation dialog
- **Edit button** → Open `RecipeFormScreen` in edit mode
- **Delete button** → Delete recipe with confirmation (same as long-press)

---

## Context

From `DISCOVERY.md`:

> The `RecipeListScreen` uses a `pickerMode` parameter to distinguish between two modes. This creates confusion and limits functionality — users can't edit recipes from the Log screen, and the interaction model changes based on context.

**Current flow from Log screen:**
```
CombinedLogScreen._onLogRecipe() (line 87-92)
  → RecipeListScreen(pickerMode: true, loggedAt: _currentDate)
    → _RecipeCard.onTap → _openRecipe()
      → if pickerMode: showModalBottomSheet(LogRecipeSheet)
```

**Key files:**
- `lib/features/recipes/recipe_list_screen.dart` — main recipe list UI
- `lib/features/logging/combined_log_screen.dart` — calls recipe list from Log tab
- `lib/features/recipes/widgets/log_recipe_sheet.dart` — bottom sheet for logging

---

## Acceptance Criteria

- [ ] Tapping a recipe opens `LogRecipeSheet` to log it (from any context)
- [ ] Long-pressing a recipe shows delete confirmation dialog with haptic feedback
- [ ] Each recipe card has an edit button (`Icons.edit`) that opens `RecipeFormScreen` in edit mode
- [ ] Delete button (`Icons.delete_outline`) remains visible in trailing actions
- [ ] Duplicate button (`Icons.copy`) is [KEPT/REMOVED — TBD]
- [ ] Recipe list works identically from Dashboard tab and Log screen
- [ ] `pickerMode` parameter removed from `RecipeListScreen`
- [ ] Tooltips updated to reflect new interactions
- [ ] Code compiles without errors

---

## Implementation

### File 1: `lib/features/recipes/recipe_list_screen.dart`

**Step 1: Remove `pickerMode` parameter (line 12-16)**
```dart
// Before
class RecipeListScreen extends ConsumerWidget {
  final bool pickerMode;
  final DateTime? loggedAt;

  const RecipeListScreen({super.key, this.pickerMode = false, this.loggedAt});

// After
class RecipeListScreen extends ConsumerWidget {
  final DateTime? loggedAt;

  const RecipeListScreen({super.key, this.loggedAt});
```

**Step 2: Simplify `_openRecipe()` method (line 101-127)**
```dart
// Remove the pickerMode branching, always log
Future<void> _openRecipe(BuildContext context, WidgetRef ref, Recipe recipe) async {
  final detail = await ref.read(recipeDetailProvider(recipe.id).future);
  if (detail == null || !context.mounted) return;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => LogRecipeSheet(detail: detail, loggedAt: loggedAt),
  );
  if (result == true && context.mounted) {
    ref.invalidate(todaysFoodProvider);
    ref.read(dataTriggerProvider.notifier).state++;
    Navigator.of(context).pop(true);
  }
}
```

**Step 3: Update `_RecipeCard` trailing actions (line 212-228)**
```dart
// Before: mode-based trailing
trailing: widget.pickerMode
    ? const Icon(Icons.chevron_right)
    : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: Icon(Icons.edit, size: 20), onPressed: widget.onTap),
          IconButton(icon: Icon(Icons.copy, size: 20), onPressed: widget.onDuplicate),
          IconButton(icon: Icon(Icons.delete_outline, size: 20), onPressed: widget.onDelete),
        ],
      ),

// After: always show edit + delete
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: const Icon(Icons.edit, size: 20),
      onPressed: widget.onTap,  // Opens edit form
      tooltip: 'Edit recipe',
    ),
    IconButton(
      icon: const Icon(Icons.delete_outline, size: 20),
      onPressed: widget.onDelete,
      tooltip: 'Delete recipe',
    ),
  ],
),
```

**Step 4: Update tooltip on card (line 198-199)**
```dart
// Before
Tooltip(
  message: widget.pickerMode ? 'Log this recipe' : 'Tap to edit',

// After
Tooltip(
  message: 'Tap to log, long-press to delete',
```

**Step 5: Remove duplicate recipe functionality (if not keeping)**
- Remove `_duplicateRecipe()` method (line 155-169)
- Remove `onDuplicate` callback from `_RecipeCard`

### File 2: `lib/features/logging/combined_log_screen.dart`

**Update `_onLogRecipe()` call (line 87-92)**
```dart
// Before
Future<void> _onLogRecipe() async {
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => RecipeListScreen(pickerMode: true, loggedAt: _currentDate),
    ),
  );
}

// After
Future<void> _onLogRecipe() async {
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => RecipeListScreen(loggedAt: _currentDate),
    ),
  );
}
```

---

## Testing Plan

### Manual Testing
1. **From Recipes tab:**
   - [ ] Tap recipe → opens edit form
   - [ ] Long-press recipe → shows delete confirmation
   - [ ] Tap edit button → opens edit form
   - [ ] Tap delete button → shows delete confirmation

2. **From Log screen (tap menu_book icon):**
   - [ ] Tap recipe → opens `LogRecipeSheet`
   - [ ] Long-press recipe → shows delete confirmation
   - [ ] Tap edit button → opens edit form
   - [ ] Tap delete button → shows delete confirmation

3. **Edit flow:**
   - [ ] Edit recipe name, save → recipe list updates
   - [ ] Edit recipe ingredients, save → macros update correctly

4. **Delete flow:**
   - [ ] Delete recipe → confirmation dialog appears
   - [ ] Confirm delete → recipe removed from list
   - [ ] Cancel delete → recipe remains

### Verification
- [ ] Run `flutter analyze > analyze.log 2>&1` and read `analyze.log` — zero issues
- [ ] Run `flutter test > test.log 2>&1` and read `test.log` — all tests pass

---

## Dependencies

None — this ticket is independent.

---

## Open Questions

1. **Should the duplicate button be kept?**
   - **Keep:** Useful for creating variations of recipes
   - **Remove:** Simplifies UI, reduces clutter
   - **Recommendation:** Remove for now, can add back if users request it

2. **Should edit button open in "edit mode" or "duplicate mode"?**
   - Per issue description: **Edit mode** (modifies existing recipe)

---

## Notes

- This change simplifies the mental model — recipe list always behaves the same way
- Long-press delete with haptic feedback is consistent with other Flutter apps
- Edit button placement in trailing row is standard Material Design pattern
