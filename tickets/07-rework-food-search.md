# Ticket 07 — Rework food search with My Foods / Search Web toggle

**Issues**: #10 (main), #1 (subsumed), #6 (subsumed), #9 (subsumed)  
**Phase**: 2  
**Dependencies**: None  
**Estimate**: ~3-4 hours

---

## Context

The current food search always queries both local DB and OpenFoodFacts API,
merging results with barcode-based dedup. This has several problems:

1. No way to search only locally-stored foods.
2. API calls on every keystroke (with debounce) — slow, uses data.
3. Recent foods are a separate section that doesn't refresh automatically.
4. "Create custom food" is inconsistently positioned.

The fix: a `SegmentedButton` toggle at the top of the search delegate
switching between **"My Foods"** (local DB only, sorted by recency) and
**"Search the Web"** (API only, no local fallback). This eliminates the
need for a separate recent-foods section and auto-refresh issues.

---

## Acceptance Criteria

### "My Foods" mode (default)
1. Shows all locally stored foods when query is empty, sorted by recency
   (most recently logged first).
2. Filters by name (LIKE) when query is non-empty, maintaining recency sort.
3. "Create custom food" ListTile is always the first item.
4. Tapping a food selects it (same behavior as current search result tap).
5. Tapping "+" on a food row opens QuickFoodLogSheet (same as current
   onQuickLog behavior).

### "Search the Web" mode
1. Shows nothing when query is empty (no recent foods section).
2. On typing, calls OpenFoodFacts API with debounce (400ms, existing behavior).
3. No "Create custom food" button.
4. Results are API-only (no local DB fallback).

### General
1. The toggle is a `SegmentedButton` with "My Foods" and "Search the Web"
   segments, placed at the top of the delegate body.
2. Switch toggles immediately clear the current results and show the
   appropriate view for the current query (or empty state).
3. Backward compatible: all existing flows (log food, recipe ingredient
   selection, quick-log) use `FoodSearchDelegate` and work unchanged.

---

## Implementation

### 7a. New DAO method — search local by recency
**File**: `lib/core/database/database.dart`

```dart
Future<List<Food>> searchLocalByRecency({String? query, int limit = 50}) async {
  // Subquery: get max(loggedAt) per foodId from food_entries
  // Main query: select foods joined with the subquery, ordered by last used desc
  final inner = selectOnly(foodEntries, distinct: true)
    ..addColumns([foodEntries.foodId, foodEntries.loggedAt.max()]);
  // ... drift doesn't support groupBy easily, so do it in Dart like getRecentFoods()
}
```

Since drift 2.31.0 has no `groupBy` on `SimpleSelectStatement`, use the same
Dart-side loop pattern as `getRecentFoods()`:

```dart
Future<List<Food>> searchLocalByRecency({String? query, int limit = 50}) async {
  final allEntries = await (select(foodEntries)
        ..where((f) => f.foodId.isNotNull())
        ..orderBy([
          (f) => OrderingTerm(expression: f.loggedAt, mode: OrderingMode.desc)
        ]))
      .get();

  final seenIds = <int>{};
  final orderedIds = <int>[];
  for (final entry in allEntries) {
    if (entry.foodId != null && seenIds.add(entry.foodId!)) {
      orderedIds.add(entry.foodId!);
    }
  }

  if (orderedIds.isEmpty) return [];

  var foods = await (select(foods)
        ..where((f) => f.id.isIn(orderedIds)))
      .get();

  if (query != null && query.trim().isNotEmpty) {
    final q = query.toLowerCase();
    foods = foods.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  // Re-sort to match recency order
  final foodMap = {for (final f in foods) f.id: f};
  return orderedIds
      .map((id) => foodMap[id])
      .whereType<Food>()
      .take(limit)
      .toList();
}
```

### 7b. Update FoodSearchService
**File**: `lib/providers/food_search_provider.dart`

Replace the merged `search()` method with two separate methods:

```dart
Future<List<FoodSearchItem>> searchLocal(String query) async {
  final results = await db.searchLocalByRecency(query: query.isEmpty ? null : query);
  return results.map(FoodSearchItem.fromFood).toList();
}

Future<List<FoodSearchItem>> searchWeb(String query) async {
  final results = await apiClient.search(query);
  return results.map(FoodSearchItem.fromFoodResult).toList();
}
```

### 7c. Redesign FoodSearchDelegate
**File**: `lib/features/logging/widgets/food_search_delegate.dart`

Complete rewrite of `_buildContent()`:

```dart
Widget _buildContent(BuildContext context) {
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'local', label: Text('My Foods')),
            ButtonSegment(value: 'web', label: Text('Search the Web')),
          ],
          selected: {_searchMode},
          onSelectionChanged: (v) => setState(() => _searchMode = v.first),
        ),
      ),
      Expanded(
        child: _searchMode == 'local'
            ? _buildLocalSearch(context)
            : _buildWebSearch(context),
      ),
    ],
  );
}
```

For local search mode:
- Show "Create custom food" ListTile always at top
- Show `_LocalFoodsList` (ConsumerWidget watching new provider or calling
  service directly) → shows all foods when query empty, filtered otherwise
- Each row: name, serving info, macros, "+" quick-log icon

For web search mode:
- Show `_DebouncedSearch` (same as current, but only API, no local merge)
- No "Create custom food" button

### 7d. Remove deprecated files
- Delete `lib/providers/recent_foods_provider.dart` (no longer needed)
- Remove `_RecentFoodsSection` from delegate
- Remove `recentFoodsProvider` import from `food_search_delegate.dart`

---

## Testing

### Unit tests (`test/providers/food_search_provider_test.dart`)
- Rewrite for new API: test `searchLocal()` returns foods sorted by recency
- Test `searchWeb()` calls API client directly
- Test local search with empty query returns all foods
- Test local search with query filters correctly
- Test web search with empty query returns empty

### Widget tests (`test/features/logging/log_food_screen_test.dart`)
- Test toggle exists and defaults to "My Foods"
- Test "My Foods" mode shows "Create custom food" at top
- Test switching to "Search the Web" clears local results
- Test tapping food in "My Foods" mode selects it
- Test tapping "+" in "My Foods" opens quick-log

### Manual tests
- Open food search from Log tab
- **Verify**: Default view is "My Foods" with all your foods listed
- **Verify**: "Create custom food" is the first item
- **Verify**: Scrolling shows foods in recency order
- Type a query
- **Verify**: List filters in real-time, still sorted by recency
- Tap "Search the Web"
- **Verify**: Empty state shown
- Type a query, wait for debounce
- **Verify**: API results appear (no local foods mixed in)
- Tap back to "My Foods"
- **Verify**: Local results shown for the same query
- Search in recipe ingredient picker
- **Verify**: Same toggle/tabs work (consistency)

---

## Files Changed

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | New `searchLocalByRecency()` DAO |
| `lib/providers/food_search_provider.dart` | Split `search()` into `searchLocal()` + `searchWeb()` |
| `lib/features/logging/widgets/food_search_delegate.dart` | Complete rewrite with SegmentedButton |
| `lib/providers/recent_foods_provider.dart` | DELETE |
| `test/providers/food_search_provider_test.dart` | Rewrite |
| `test/features/logging/log_food_screen_test.dart` | Update |

---

## Open Questions

- Should "My Foods" mode support quick-log (+) on each row? The current
  recent-foods section does. Yes — carry this over for consistency.
- The 50-item limit for local search — is that enough? For power users with
  hundreds of foods, maybe not. Consider pagination as a follow-up.
- The `searchLocalByRecency()` Dart-side loop fetches ALL food_entries every
  time. For users with thousands of entries this could be slow. Consider an
  indexed SQL approach later if performance is an issue.
