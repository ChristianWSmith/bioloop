# T3: Make recent foods refresh reactively

**Issue:** #1
**Effort:** ~2 min
**Dependencies:** None

## Context

`recentFoodsProvider` (`lib/providers/recent_foods_provider.dart`) is a `FutureProvider` that fetches the 10 most recently logged distinct foods. It's used in `_RecentFoodsSection` within `FoodSearchDelegate` to show recent foods when the user opens a food search.

Current behaviour: `recentFoodsProvider` only reads the `databaseProvider` (one-shot, no watch). Since `databaseProvider` never changes (it's overridden once in `main.dart`), the provider **never invalidates** after its initial creation. This means:

1. User logs a new food → `dataTriggerProvider` is incremented
2. User opens the recipe ingredient search → recent foods list is stale, missing the newly logged food
3. Only a full app restart refreshes recent foods

The `dataTriggerProvider` (`StateProvider<int>`) is incremented at every food log/delete/mutation site:
- `log_food_screen.dart:194` — normal food log
- `log_food_screen.dart:291` — recipe log from log screen
- `log_food_screen.dart:401` — delete from today's entries
- `quick_food_log_sheet.dart:95` — quick-log
- `log_recipe_sheet.dart` — recipe log from recipe detail

## Intent

Make `recentFoodsProvider` reactive to data mutations so recent foods update immediately without requiring an app restart.

## Changes

**File:** `lib/providers/recent_foods_provider.dart`

Add `ref.watch(dataTriggerProvider)` to the provider's build function. This establishes a dependency that causes the provider to re-execute whenever `dataTriggerProvider` is incremented.

Currently:
```dart
final recentFoodsProvider = FutureProvider<List<RecentFoodItem>>((ref) async {
  final db = ref.read(databaseProvider);
  ...
});
```

After:
```dart
final recentFoodsProvider = FutureProvider<List<RecentFoodItem>>((ref) async {
  ref.watch(dataTriggerProvider);
  final db = ref.read(databaseProvider);
  ...
});
```

Note: `ref.watch` vs `ref.read` — `watch` is correct here because we need reactivity. The `dataTriggerProvider` import must be added.

## Testing

- **Manual:** Open the app, log a food item from OpenFoodFacts or create a custom food. Open the search delegate on any screen. Verify the newly logged food appears under "Recent Foods". Do this from both the log tab's search and the recipe ingredient search.
- **Integration test:** Create in-memory DB, insert food entries, create `ProviderContainer` with override for `databaseProvider` and `dataTriggerProvider`. Verify `recentFoodsProvider` resolves with correct items. Increment `dataTriggerProvider`, verify provider invalidates and re-fetches.
