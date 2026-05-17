# Ticket 003: Fix stale food list after deletion in search

**Issue:** #3 from issues.txt
**Size:** Medium (~45 min)
**Dependencies:** None

## Problem

After deleting a food from the search screen while on "My Foods" tab, the deleted food remains visible until the user leaves and re-enters the search screen.

## Root Cause

`_LocalSearchContent` (`food_search_delegate.dart:197-338`) uses a `FutureBuilder` that calls `searchService.searchLocal(query)` directly in its `build` method. The `FutureBuilder` caches its future result. After deletion:

1. `_deleteFood` in `combined_log_screen.dart:121-171` calls `db.deleteFood(food.id)`
2. It increments `dataTriggerProvider` and invalidates `todaysFoodProvider`
3. But `_LocalSearchContent` is a `StatelessWidget` with a `FutureBuilder` that does **not** watch `dataTriggerProvider`
4. The `FutureBuilder`'s future has already resolved with stale data
5. No `setState()` is called after the async deletion completes
6. The `SearchDelegate` framework doesn't trigger a rebuild of `buildResults`/`buildSuggestions`

The `dataTriggerProvider` mechanism already exists for this exact purpose — it just isn't wired up to the local food list.

## Acceptance Criteria

- [ ] After deleting a food from "My Foods" tab, the food disappears from the list immediately
- [ ] Deleting via long-press also causes immediate removal
- [ ] Deleting via the trailing delete icon button also causes immediate removal
- [ ] The fix uses the existing `dataTriggerProvider` mechanism (consistent with app architecture)
- [ ] No regression: "Search the Web" tab still works correctly
- [ ] `flutter analyze` passes with zero new issues
- [ ] All existing tests pass
- [ ] New widget test verifies list refreshes after deletion

## Files to Change

| File | Change |
|------|--------|
| `lib/providers/local_food_list_provider.dart` | **New file** — `FutureProvider.family<List<FoodSearchItem>, String>` that watches `dataTriggerProvider` and calls `searchService.searchLocal(query)` |
| `lib/features/logging/widgets/food_search_delegate.dart` | Convert `_LocalSearchContent` from `StatelessWidget` to `ConsumerWidget`; replace `FutureBuilder` with `ref.watch(localFoodListProvider(query).when(...))`; thread `WidgetRef` through `_FoodSearchContent` |

## Implementation Details

### New provider

```dart
final localFoodListProvider = FutureProvider.family<List<FoodSearchItem>, String>((ref, query) async {
  ref.watch(dataTriggerProvider);
  final service = ref.watch(foodSearchServiceProvider);
  return service.searchLocal(query);
});
```

### Widget changes

- `_FoodSearchContent` is already a `StatefulWidget` — it needs to become a `ConsumerStatefulWidget` (or receive `WidgetRef` from a parent `ConsumerWidget`)
- `_LocalSearchContent` becomes a `ConsumerWidget`
- Replace the `FutureBuilder` with:
  ```dart
  ref.watch(localFoodListProvider(query).when(
    data: (items) => _buildList(items),
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => const Center(child: Text('Error')),
  ))
  ```
- No changes to `_deleteFood` in `combined_log_screen.dart` — it already increments `dataTriggerProvider`

## Testing

### Widget test
Add to `test/features/logging/search_delegate_test.dart`:
1. Seed a local food into the DB
2. Open search delegate, verify food appears
3. Long-press or tap delete on the food
4. Verify food disappears from the list without leaving the search screen

### Existing tests
The existing `search_delegate_test.dart` tests toggle behavior and should remain unaffected.

## Notes

- The `_WebSearchContent` widget also uses a `FutureBuilder` but doesn't need this fix — web search results are never mutated locally, so staleness isn't an issue.
- This change makes the local search list reactive to *any* data mutation (food log, weight entry, delete), which is correct behavior — the recency ordering should update when food entries change.
