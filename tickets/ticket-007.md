# Ticket 007 — Log tab rework: recent foods + today's entries with delete

**Issues:** #5, #11
**Estimate:** ~3 hr
**Depends on:** nothing (but may conflict with Ticket 006 if both modify `log_food_screen.dart`)

---

## Acceptance criteria

### Recent foods (#11)
- [ ] Recent foods provider returns last 10 distinct foods (by `foodId`) ordered by recency
- [ ] Uses `food_entries` table (GROUP BY query) — no new table required
- [ ] Recent foods appear when the search delegate is opened with an empty query
- [ ] Each recent food tile shows name, macros, and last-used date
- [ ] Tapping a recent food selects it immediately (same as search result)

### Today's entries with delete (#5)
- [ ] Today's logged food entries are displayed on the Dashboard or Log tab
- [ ] Each entry shows: name, meal type, macros, log time
- [ ] Each entry has a delete button (trash icon or swipe-to-delete)
- [ ] Delete shows confirmation dialog
- [ ] After deletion, macro rings and entry list update immediately
- [ ] "No entries logged today" shown when today has no entries

---

## Context from DISCOVERY.md

### Recent foods — query-based approach (no schema change)

```sql
SELECT foodId, name, servingLabel, servingSizeGrams,
       caloriesPerServing, proteinPerServing, carbsPerServing, fatPerServing,
       barcode, source, MAX(loggedAt) as lastUsed
FROM food_entries
WHERE foodId IS NOT NULL
GROUP BY foodId
ORDER BY lastUsed DESC
LIMIT 10
```

This returns the last 10 distinct foods the user has logged. The `foodId IS NOT NULL` filter excludes ad-hoc entries and recipes (which have `recipeId` set instead).

### Drift query

```dart
Future<List<_RecentFoodRow>> getRecentFoods({int limit = 10}) async {
  return await (select(foodEntries)
        ..where((f) => f.foodId.isNotNull())
        ..groupBy([(f) => f.foodId!])  // note: drift requires non-nullable expression
        ..orderBy([
          (f) => OrderingTerm(
            expression: f.loggedAt,
            mode: OrderingMode.desc,
          ),
        ])
        ..limit(limit))
      .map((row) => _RecentFoodRow(
        foodId: row.foodId,
        name: row.name,
        servingLabel: row.servingLabel,
        // ... etc
        lastUsed: row.loggedAt,
      ))
      .get();
}
```

**Note:** Drift may not support `GROUP BY` on a nullable column directly. Alternative: filter in-memory, or add a `NOT NULL` check after grouping. Simpler approach: two queries — first get distinct `foodId`s ordered by MAX(loggedAt), then fetch food details from `foods` table.

```dart
Future<List<Food>> getRecentFoods({int limit = 10}) async {
  // Get distinct food IDs with their most recent log date
  final recentIds = await (select(foodEntries)
        ..where((f) => f.foodId.isNotNull())
        ..groupBy([(f) => f.foodId!])
        ..orderBy([
          OrderingTerm(
            expression: f.loggedAt.max(),
            mode: OrderingMode.desc,
          ),
        ])
        ..limit(limit))
      .map((row) => row.foodId!)
      .get();

  if (recentIds.isEmpty) return [];

  // Fetch full food records
  return await (select(foods)
        ..where((f) => f.id.isIn(recentIds)))
      .get();
}
```

### UX integration point

The `FoodSearchDelegate` (`food_search_delegate.dart:44-65`) currently shows:
- "Create custom food" list tile (always)
- Divider + debounced search results (only when `query.isNotEmpty`)

**Change:** When `query.isEmpty`, show "Recent foods" section before the "Create custom food" tile:

```dart
Widget _buildContent(BuildContext context) {
  return ListView(
    children: [
      if (query.isEmpty)
        _RecentFoodsSection(onSelectItem: (item) => close(context, item))
      else ...[
        ListTile(/* ... create custom food ... */),
        const Divider(),
        _DebouncedSearch(query: query, ...),
      ],
    ],
  );
}
```

### Today's entries — UX placement

Decision needed: Dashboard tab or Log tab?

**Recommended: Log tab** — keeps the Dashboard focused on summary (macro rings, sparkline) and groups the editing/deletion UI together with the creation UI where the user expects to manage their food.

Layout:
```
┌──────────────────────┐
│ [Search foods...    ]│  ← search bar (opens delegate)
│ [Recipes] [Templates]│  ← action buttons
├──────────────────────┤
│ Today's Entries      │  ← section header
│                      │
│ Breakfast            │
│ ├ Oatmeal       400c │  [🗑]
│ ├ Coffee         50c │  [🗑]
│ Lunch                │
│ ├ Chicken Rice  650c │  [🗑]
└──────────────────────┘
```

---

## Testing

### Manual test — recent foods
1. Log 3 different foods via search (chicken, rice, broccoli)
2. Open search bar → verify recent foods show chicken, rice, broccoli (most recent first)
3. Tap chicken → verify it selects and populates the log form

### Manual test — delete from log tab
1. Log 2-3 foods for today
2. Go to Log tab → verify today's entries are listed below the search bar
3. Tap delete on one entry → confirm dialog → verify entry removed
4. Verify macro count in snackbar/UI updates

### Manual test — empty state
1. No food logged today → Log tab shows "No entries logged today"
2. Log food → entry appears immediately
3. Delete all today's entries → "No entries logged today" reappears

### Automated test ideas
- Unit test: `getRecentFoods()` returns correct order and limit
- Widget test: recent foods section appears in search delegate
- Widget test: today's entries section renders with correct data
- Widget test: delete button removes entry and updates UI

---

## Files to create/modify

- **Create:** `lib/providers/recent_foods_provider.dart`
- **Modify:** `lib/core/database/database.dart` — add `getRecentFoods()` DAO method
- **Modify:** `lib/features/logging/log_food_screen.dart` — add today's entries section
- **Modify:** `lib/features/logging/widgets/food_search_delegate.dart` — add recent foods section
- **Modify:** `lib/providers/food_log_provider.dart` — expose recent foods if needed
