# Ticket 6: Food Edit/Delete UI in My Foods Tab

**Priority:** Medium  
**Complexity:** Medium  
**Estimated effort:** 45 minutes  
**Files:** `lib/features/logging/widgets/food_search_delegate.dart`

---

## Description

Add edit and delete functionality to the "My Foods" tab in the food search view. Users should be able to edit saved foods or delete them with confirmation.

---

## Context

From `DISCOVERY.md`:

> The "My Foods" tab in `FoodSearchDelegate` displays a list of local foods. Current interaction: Tap → Opens `QuickFoodLogSheet`. No edit or delete functionality exists.

**Current behavior:**
- Tap food → Opens `QuickFoodLogSheet` to log it
- No edit button
- No delete button or long-press action

**New behavior:**
- **Tap** → Open `QuickFoodLogSheet` to log (unchanged)
- **Long-press** → Delete food with confirmation dialog
- **Edit button** → Open `ManualFoodForm` in edit mode
- **Delete button** → Delete food with confirmation (same as long-press)

**Key files:**
- `lib/features/logging/widgets/food_search_delegate.dart` — main food search UI
- `lib/features/logging/widgets/manual_food_form.dart` — edit form (modified in Ticket 7)

---

## Acceptance Criteria

- [ ] Each food item in "My Foods" tab has an edit button (`Icons.edit`) in trailing actions
- [ ] Each food item has a delete button (`Icons.delete_outline`) in trailing actions
- [ ] Long-pressing a food item shows delete confirmation dialog with haptic feedback
- [ ] Tapping edit button opens `ManualFoodForm` pre-filled with food data
- [ ] Tapping delete button shows delete confirmation dialog
- [ ] Delete confirmation dialog shows warning if food is used in log entries
- [ ] Confirming delete removes food and updates list
- [ ] Canceling delete keeps food in list
- [ ] Tap on food item (not buttons) still opens `QuickFoodLogSheet`
- [ ] Code compiles without errors

---

## Implementation

### File: `lib/features/logging/widgets/food_search_delegate.dart`

**Step 1: Update `_LocalSearchContent` parameters**

Add callbacks for edit and delete:

```dart
class _LocalSearchContent extends StatelessWidget {
  final String query;
  final FoodSearchService searchService;
  final VoidCallback onCreateCustomFood;
  final Future<void> Function(FoodSearchItem)? onQuickLog;
  final void Function(FoodSearchItem item) onSelectItem;
  final void Function(Food food)? onEditFood;      // NEW
  final Future<void> Function(Food food)? onDeleteFood;  // NEW

  const _LocalSearchContent({
    required this.query,
    required this.searchService,
    required this.onCreateCustomFood,
    this.onQuickLog,
    required this.onSelectItem,
    this.onEditFood,
    this.onDeleteFood,
  });
```

**Step 2: Update ListTile to include trailing buttons**

Replace the current ListTile (lines 224-239):

```dart
// Before (lines 224-239)
return ListTile(
  title: Text(item.name),
  subtitle: Text(
    '$macroText\n${item.servingLabel}',
  ),
  isThreeLine: true,
  onTap: () => onQuickLog != null
      ? onQuickLog!(item)
      : onSelectItem(item),
);

// After
return ListTile(
  title: Text(item.name),
  subtitle: Text(
    '$macroText\n${item.servingLabel}',
  ),
  isThreeLine: true,
  onTap: () => onQuickLog != null
      ? onQuickLog!(item)
      : onSelectItem(item),
  onLongPress: () async {
    if (onDeleteFood != null) {
      final food = Food(
        id: item.localId!,
        name: item.name,
        servingLabel: item.servingLabel,
        servingQuantity: item.servingQuantity,
        servingUnit: item.servingUnit,
        caloriesPerServing: item.caloriesPerServing,
        proteinPerServing: item.proteinPerServing,
        carbsPerServing: item.carbsPerServing,
        fatPerServing: item.fatPerServing,
        barcode: item.barcode,
        brand: item.brand,
        source: item.source,
        createdAt: '',
      );
      await onDeleteFood!(food);
    }
  },
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.edit, size: 20),
        onPressed: () {
          if (onEditFood != null) {
            final food = Food(
              id: item.localId!,
              name: item.name,
              servingLabel: item.servingLabel,
              servingQuantity: item.servingQuantity,
              servingUnit: item.servingUnit,
              caloriesPerServing: item.caloriesPerServing,
              proteinPerServing: item.proteinPerServing,
              carbsPerServing: item.carbsPerServing,
              fatPerServing: item.fatPerServing,
              barcode: item.barcode,
              brand: item.brand,
              source: item.source,
              createdAt: '',
            );
            onEditFood!(food);
          }
        },
        tooltip: 'Edit food',
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () async {
          if (onDeleteFood != null) {
            final food = Food(
              id: item.localId!,
              name: item.name,
              servingLabel: item.servingLabel,
              servingQuantity: item.servingQuantity,
              servingUnit: item.servingUnit,
              caloriesPerServing: item.caloriesPerServing,
              proteinPerServing: item.proteinPerServing,
              carbsPerServing: item.carbsPerServing,
              fatPerServing: item.fatPerServing,
              barcode: item.barcode,
              brand: item.brand,
              source: item.source,
              createdAt: '',
            );
            await onDeleteFood!(food);
          }
        },
        tooltip: 'Delete food',
      ),
    ],
  ),
);
```

**Step 3: Update `FoodSearchDelegate` to pass callbacks**

In `buildResults` and `buildSuggestions` (lines 66-98), update the `_FoodSearchContent` instantiation:

```dart
// Add parameters to FoodSearchDelegate class
class FoodSearchDelegate extends SearchDelegate<FoodSearchItem?> {
  final FoodSearchService searchService;
  final OpenFoodFactsClient apiClient;
  final VoidCallback onCreateCustomFood;
  final Future<void> Function(FoodSearchItem)? onQuickLog;
  final void Function(Food)? onEditFood;      // NEW
  final Future<void> Function(Food)? onDeleteFood;  // NEW
  String _searchMode = 'local';

  FoodSearchDelegate({
    required this.searchService,
    required this.apiClient,
    required this.onCreateCustomFood,
    this.onQuickLog,
    this.onEditFood,      // NEW
    this.onDeleteFood,    // NEW
  });
```

Then pass to `_FoodSearchContent`:

```dart
@override
Widget buildResults(BuildContext context) => _FoodSearchContent(
      query: query,
      searchService: searchService,
      searchMode: _searchMode,
      onSearchModeChanged: (v) => _searchMode = v,
      onCreateCustomFood: onCreateCustomFood,
      onQuickLog: onQuickLog != null
          ? (item) async {
              final nav = Navigator.of(context);
              await onQuickLog!(item);
              nav.pop<FoodSearchItem?>(null);
            }
          : null,
      onSelectItem: (item) => close(context, item),
      onEditFood: onEditFood,      // NEW
      onDeleteFood: onDeleteFood,  // NEW
    );
```

Do the same for `buildSuggestions`.

**Step 4: Update `_FoodSearchContent` to pass callbacks down**

```dart
class _FoodSearchContent extends StatefulWidget {
  // ... existing fields ...
  final void Function(Food)? onEditFood;      // NEW
  final Future<void> Function(Food)? onDeleteFood;  // NEW

  const _FoodSearchContent({
    // ... existing params ...
    this.onEditFood,      // NEW
    this.onDeleteFood,    // NEW
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ... segmented toggle ...
        Expanded(
          child: _localSearchMode == 'local'
              ? _LocalSearchContent(
                  query: widget.query,
                  searchService: widget.searchService,
                  onCreateCustomFood: widget.onCreateCustomFood,
                  onQuickLog: widget.onQuickLog,
                  onSelectItem: widget.onSelectItem,
                  onEditFood: widget.onEditFood,      // NEW
                  onDeleteFood: widget.onDeleteFood,  // NEW
                )
              : _WebSearchContent(...),
        ),
      ],
    );
  }
}
```

**Step 5: Update callers of `FoodSearchDelegate`**

In `lib/features/logging/combined_log_screen.dart` (line 58-70):

```dart
final result = await showSearch<FoodSearchItem?>(
  context: context,
  delegate: FoodSearchDelegate(
    searchService: searchService,
    apiClient: apiClient,
    onCreateCustomFood: () => _pendingCreateCustom = true,
    onQuickLog: (item) async {
      await _showQuickLogSheet(item);
    },
    onEditFood: (food) {
      _openEditFood(food);  // NEW - implement this
    },
    onDeleteFood: (food) async {
      await _deleteFood(food);  // NEW - implement this
    },
  ),
);
```

Add the new methods to `_CombinedLogScreenState`:

```dart
Future<void> _openEditFood(Food food) async {
  final edited = await Navigator.of(context).push<Food>(
    MaterialPageRoute(
      builder: (_) => ManualFoodForm(existingFood: food),  // Requires Ticket 7
    ),
  );
  if (edited != null && mounted) {
    // Optionally show snackbar or refresh
  }
}

Future<void> _deleteFood(Food food) async {
  // Count entries that reference this food
  final db = ref.read(databaseProvider);
  final allEntries = await db.getEntriesPaginated(limit: 1000);
  final entryCount = allEntries.where((e) => e.foodId == food.id).length;

  if (entryCount > 0 && !mounted) return;

  // Show confirmation dialog with warning
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete food?'),
      content: entryCount > 0
          ? Text('Delete "${food.name}"? This will also delete $entryCount log entries.')
          : Text('Delete "${food.name}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !mounted) return;

  try {
    // Delete in FK-safe order (entries first, then food)
    await db.transaction(() async {
      // Delete referencing entries
      final entries = await db.getEntriesPaginated(limit: 1000);
      for (final entry in entries) {
        if (entry.foodId == food.id) {
          await db.deleteEntry(entry.id);
        }
      }
      // Delete the food itself (need to add this method to DB)
      // await db.deleteFood(food.id);
    });

    if (mounted) {
      // Optionally show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${food.name} deleted')),
      );
    }
  } catch (e) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to delete: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
```

---

## Testing Plan

### Manual Testing

1. **From Log screen (tap search icon):**
   - [ ] Toggle to "My Foods" tab
   - [ ] Tap edit button on a food → opens edit form
   - [ ] Tap delete button on a food → shows confirmation dialog
   - [ ] Long-press a food → shows confirmation dialog
   - [ ] Tap food item (not buttons) → opens `QuickFoodLogSheet`

2. **Delete flow:**
   - [ ] Delete food with no log entries → confirms, deletes, shows snackbar
   - [ ] Delete food with log entries → warns about entries, confirms, deletes both
   - [ ] Cancel delete → food remains in list

3. **Edit flow:**
   - [ ] Edit food name → saves, list updates
   - [ ] Edit macros → saves, future logs use new values
   - [ ] Cancel edit → changes discarded

### Verification
- [ ] Run `flutter analyze > analyze.log 2>&1` and read `analyze.log` — zero issues
- [ ] Run `flutter test > test.log 2>&1` and read `test.log` — all tests pass

---

## Dependencies

- **Requires:** Ticket 7 (ManualFoodForm edit support)
- **Required by:** None — completes food edit/delete feature

---

## Notes

- Trailing buttons should be compact (size 20) to avoid crowding
- Long-press should provide haptic feedback (use `HapticFeedback.mediumImpact()`)
- Delete confirmation dialog should clearly warn about cascade delete
- Edit button opens form in "edit mode" (modifies existing food, not duplicate)
- Past log entries are deleted when food is deleted (cascade)
- Editing a food does NOT update past log entries (they remain as snapshots)
