# Ticket #4: [UX] Improve recipe management discoverability

**Priority:** 🟢 Low-Medium  
**Effort:** Small (2-3 hours)  
**Status:** Pending  
**Assignee:** Unassigned  
**Created:** May 16, 2026  
**Tags:** `ux`, `recipes`, `discoverability`, `gesture`

---

## Problem Statement

Users are confused about how to edit recipes. While edit functionality exists, it's not discoverable enough. Additionally, long-press delete has no visual cue or haptic feedback.

**User Impact:** Users think they can't edit recipes (Issue #1) or don't know they can long-press to delete (Issue #3), leading to frustration and support requests.

### Discovery Findings

From `DISCOVERY.md`:
- Recipe editing **IS implemented** at `recipe_list_screen.dart:116-120`
- Long-press delete **IS implemented** at `recipe_list_screen.dart:219`
- Both features suffer from poor discoverability

---

## Current Implementation

### Edit Flow (Works, Not Obvious)

**File:** `lib/features/recipes/recipe_list_screen.dart:100-120`

```dart
Future<void> _openRecipe(...) async {
  if (pickerMode) {
    // Picker mode: go straight to logging
    // ...
  } else {
    // Management mode: navigate to edit form
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeFormScreen(recipeId: recipe.id),  // ← Edit mode
      ),
    );
  }
}
```

### Recipe Card UI (Icons Present, Not Obvious)

**File:** `lib/features/recipes/recipe_list_screen.dart:186-221`

```dart
class _RecipeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.restaurant_menu),
        title: Text(recipe.name),
        subtitle: Text('${recipe.servingSize.toStringAsFixed(0)} ${recipe.servingLabel}'),
        trailing: pickerMode
            ? const Icon(Icons.chevron_right)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onTap,
                    tooltip: 'Edit recipe',  // ← Tooltip exists
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: onDuplicate,
                    tooltip: 'Duplicate recipe',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Delete recipe',
                  ),
                ],
              ),
        onTap: onTap,
        onLongPress: pickerMode ? null : onDelete,  // ← Long-press works
      ),
    );
  }
}
```

### Issues

1. **Edit icon confusion**: Three icons (edit, copy, delete) may overwhelm users
2. **Long-press not discoverable**: No visual cue that long-press is available
3. **No haptic feedback**: Long-press feels unresponsive
4. **Mode confusion**: Users accessing from Log screen (picker mode) can't edit

---

## Acceptance Criteria

### Functional
- [ ] Recipe card has tooltip: "Tap to edit" (management mode only)
- [ ] Long-press on recipe card triggers haptic feedback
- [ ] Long-press shows visual feedback (card highlight or scale animation)
- [ ] Edit icon tooltip remains: "Edit recipe"
- [ ] Picker mode unchanged: no edit/delete actions, tap to log only

### Visual Feedback
- [ ] Long-press: card scales down slightly (0.95x) or changes background color
- [ ] Long-press: haptic feedback (`HapticFeedback.mediumImpact()`)
- [ ] Release: card returns to normal size/color
- [ ] Animation duration: 150-200ms (smooth, not sluggish)

### Edge Cases
- [ ] Empty state unchanged: "No recipes yet. Tap + to create one."
- [ ] Loading state unchanged: CircularProgressIndicator
- [ ] Error state unchanged: error message display
- [ ] Picker mode: no changes to visual feedback (tap to log only)

### Non-Functional
- [ ] No console errors during long-press
- [ ] Haptic feedback only on long-press (not on tap)
- [ ] Performance: no frame drops during animation
- [ ] Accessibility: screen readers announce "Double-tap to edit, long-press to delete"

---

## Technical Implementation

### Files to Modify

1. **`lib/features/recipes/recipe_list_screen.dart`**
   - Add `Tooltip` wrapper around card
   - Add `GestureDetector` for long-press with haptic feedback
   - Add animation controller for visual feedback

2. **`test/features/recipes/recipes_test.dart`**
   - Add test: long-press gesture triggers delete dialog

### Code Changes

#### Change 1: Add Tooltip to Card

**File:** `lib/features/recipes/recipe_list_screen.dart:186-195`

**Current:**
```dart
class _RecipeCard extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        // ...
      ),
    );
  }
}
```

**Updated:**
```dart
class _RecipeCard extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: pickerMode ? 'Log this recipe' : 'Tap to edit',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          // ...
        ),
      ),
    );
  }
}
```

#### Change 2: Add Long-Press Haptic Feedback

**File:** `lib/features/recipes/recipe_list_screen.dart:1-10`

**Add import:**
```dart
import 'package:flutter/services.dart';  // ← For HapticFeedback
```

**File:** `lib/features/recipes/recipe_list_screen.dart:219`

**Current:**
```dart
onLongPress: pickerMode ? null : onDelete,
```

**Updated:**
```dart
onLongPress: pickerMode
    ? null
    : () async {
        await HapticFeedback.mediumImpact();  // ← Haptic feedback
        onDelete();
      },
```

#### Change 3: Add Visual Feedback (Scale Animation)

**Option A: Simple approach with AnimatedScale**

**File:** `lib/features/recipes/recipe_list_screen.dart:171-176`

**Add state variable:**
```dart
class _RecipeCard extends StatefulWidget {  // ← Change to StatefulWidget
  final Recipe recipe;
  final bool pickerMode;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _RecipeCard({
    required this.recipe,
    required this.pickerMode,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
  });
}
```

**Add state class:**
```dart
class _RecipeCardState extends State<_RecipeCard> {
  bool _isLongPressing = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.pickerMode ? 'Log this recipe' : 'Tap to edit',
      child: AnimatedScale(
        scale: _isLongPressing ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Card(
          color: _isLongPressing
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            // ... existing content
            onLongPress: widget.pickerMode
                ? null
                : () async {
                    setState(() => _isLongPressing = true);
                    await HapticFeedback.mediumImpact();
                    widget.onDelete();
                    setState(() => _isLongPressing = false);
                  },
          ),
        ),
      ),
    );
  }
}
```

**Note:** This requires converting `_RecipeCard` from `StatelessWidget` to `StatefulWidget`.

---

## Testing Plan

### Widget Tests (Add to `test/features/recipes/recipes_test.dart`)

**Test 1: Long-press triggers delete dialog**
```dart
testWidgets('long-press recipe triggers delete dialog', (tester) async {
  final db = AppDatabase.createInMemory();
  addTearDown(() => db.close());
  final now = DateTime.now().toIso8601String();

  await db.insertRecipe(RecipesCompanion.insert(
    name: 'To Delete',
    servingSize: 100,
    servingLabel: 'g',
    createdAt: now,
    updatedAt: now,
  ));

  await tester.pumpWidget(buildTestApp(db));
  await tester.pumpAndSettle();

  // Verify recipe is visible
  expect(find.text('To Delete'), findsOneWidget);

  // Long-press the recipe card
  await tester.longPress(find.text('To Delete'));
  await tester.pumpAndSettle();

  // Verify delete dialog appears
  expect(find.text('Delete recipe?'), findsOneWidget);
  expect(find.text('Delete'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
});
```

**Test 2: Long-press in picker mode does nothing**
```dart
testWidgets('long-press in picker mode does nothing', (tester) async {
  final db = AppDatabase.createInMemory();
  addTearDown(() => db.close());
  final now = DateTime.now().toIso8601String();

  await db.insertRecipe(RecipesCompanion.insert(
    name: 'Test Recipe',
    servingSize: 100,
    servingLabel: 'g',
    createdAt: now,
    updatedAt: now,
  ));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        home: RecipeListScreen(pickerMode: true),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Long-press the recipe card
  await tester.longPress(find.text('Test Recipe'));
  await tester.pumpAndSettle();

  // Verify no dialog appears
  expect(find.text('Delete recipe?'), findsNothing);
});
```

**Test 3: Tooltip shows correct message**
```dart
testWidgets('tooltip shows edit message in management mode', (tester) async {
  final db = AppDatabase.createInMemory();
  addTearDown(() => db.close());

  await tester.pumpWidget(buildTestApp(db));
  await tester.pumpAndSettle();

  // Find the tooltip (may require pumping for tooltip to appear)
  final tooltipFinder = find.byType(Tooltip);
  expect(tooltipFinder, findsOneWidget);

  final tooltip = tester.widget<Tooltip>(tooltipFinder);
  expect(tooltip.message, 'Tap to edit');
});
```

### Manual Testing Checklist

1. **Management mode (Recipes tab)**
   - [ ] Long-press recipe card → haptic feedback felt
   - [ ] Long-press recipe card → card scales down/highlights
   - [ ] Long-press → release → delete dialog appears
   - [ ] Tap recipe card → edit screen opens
   - [ ] Hover over card (desktop/web) → tooltip shows "Tap to edit"

2. **Picker mode (Log screen → "Log recipe")**
   - [ ] Long-press recipe card → nothing happens
   - [ ] Tap recipe card → log sheet opens
   - [ ] Hover over card → tooltip shows "Log this recipe"

3. **Edge cases**
   - [ ] Empty state → no tooltips or gestures
   - [ ] Loading state → no tooltips or gestures
   - [ ] Error state → no tooltips or gestures

4. **Accessibility**
   - [ ] Screen reader announces "Tap to edit" (management mode)
   - [ ] Screen reader announces "Long-press to delete"
   - [ ] Screen reader announces "Log this recipe" (picker mode)

---

## Definition of Done

- [ ] Code changes implemented (convert to StatefulWidget, add animations)
- [ ] Tooltip added with correct messages for both modes
- [ ] Haptic feedback on long-press (management mode only)
- [ ] Visual feedback on long-press (scale + color change)
- [ ] Widget tests added and passing (3 new tests)
- [ ] Manual testing checklist complete
- [ ] No regressions in existing recipe tests (`flutter test test/features/recipes/`)
- [ ] `flutter analyze` passes with zero issues
- [ ] Accessibility verified (screen reader announcements)

---

## Dependencies

- None (UI-only change, no data model changes)

---

## References

- Discovery report: `DISCOVERY.md` (Issues #1 and #3 sections)
- Related files:
  - `lib/features/recipes/recipe_list_screen.dart:171-221`
  - `test/features/recipes/recipes_test.dart:516-615`

---

## Alternative Approaches Considered

### Option A: Swipe-to-Dismiss (Rejected)

**Approach:** Replace long-press with swipe-to-dismiss for delete

**Pros:**
- More standard Material Design pattern
- No hidden gestures (swipe is more discoverable)

**Cons:**
- Conflicts with ListView scroll gestures
- Requires more code (Dismiss widget, different confirmation pattern)
- Loses explicit confirmation dialog (deleted immediately or needs undo snackbar)

**Decision:** Keep long-press, improve feedback

### Option B: Add "Delete" text to trailing row (Rejected)

**Approach:** Replace delete icon with text button: "Edit | Duplicate | Delete"

**Pros:**
- More explicit, no guesswork
- Larger tap target

**Cons:**
- Takes more horizontal space
- Visual clutter (3 text buttons + icons)
- Doesn't solve long-press discoverability

**Decision:** Keep icons, improve tooltips and feedback

### Option C: Add "Edit" button to card subtitle (Rejected)

**Approach:** Add tappable "Edit" text link in subtitle

**Pros:**
- Very explicit
- No icon interpretation needed

**Cons:**
- Redundant with edit icon
- Wastes vertical space
- Doesn't match Material Design card patterns

**Decision:** Keep current layout, improve discoverability

---

## Notes

**Haptic Feedback Platform Support:**
- iOS: Full support for `HapticFeedback.mediumImpact()`
- Android: Support varies by device/manufacturer
- Web/Desktop: No haptic feedback (silent no-op)

**Animation Performance:**
- `AnimatedScale` is GPU-accelerated
- Should maintain 60fps on all supported devices
- Test on low-end devices if possible

**Accessibility:**
- Consider adding `Semantics` widget for custom actions
- Screen readers should announce both tap and long-press actions
- Test with VoiceOver (iOS) and TalkBack (Android)
