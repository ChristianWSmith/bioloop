# Discovery: Food Search Improvements

## Session Date
2026-05-19

## Issues Addressed

Three issues identified in `issues.txt`:

1. **Brand not displayed** — The `brand` column exists in the `foods` table but is never shown in the UI or editable when creating custom foods.
2. **Web search tap logs immediately** — Tapping an OpenFoodFacts result in "Search the Web" mode logs the food directly, giving the user no chance to review or adjust values before logging.
3. **"My Foods" sorting** — Foods should be sorted with recently imported OFF foods above recently logged foods. Once an imported food is logged, it loses its "recently imported" status and falls into the normal recency order.

---

## Current Architecture

### Data Model

**`foods` table** (`lib/core/database/tables/foods.dart`):
| Column | Type | Notes |
|--------|------|-------|
| `id` | int | Auto-increment PK |
| `name` | text | Indexed |
| `servingLabel` | text | e.g. "100g", "1 cup" |
| `servingQuantity` | real | Default 1.0 |
| `servingUnit` | text | Default 'serving' |
| `caloriesPerServing` | real | |
| `proteinPerServing` | real | |
| `carbsPerServing` | real | |
| `fatPerServing` | real | |
| `barcode` | text | Nullable, unique |
| `brand` | text | Nullable — **exists but unused in UI** |
| `source` | text | 'manual' or 'open_food_facts' |
| `createdAt` | text | ISO 8601 timestamp |

**`FoodSearchItem`** (`lib/providers/food_search_provider.dart`):
Unified model wrapping both DB foods and API results. Has `localId` (null for web results), `brand`, `source` fields already populated.

**`FoodResult`** (`lib/core/api/models/food_result.dart`):
Parsed from OpenFoodFacts JSON. Includes `brand` from `json['brands']`.

### Key Files

| File | Purpose |
|------|---------|
| `lib/features/logging/widgets/food_search_delegate.dart` | SearchDelegate, local/web content widgets, segmented toggle |
| `lib/features/logging/widgets/manual_food_form.dart` | Create/edit custom food form |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | Modal sheet for logging a food |
| `lib/features/logging/combined_log_screen.dart` | Main log screen, entry point for search |
| `lib/providers/food_search_provider.dart` | FoodSearchService, FoodSearchItem, providers |
| `lib/providers/local_food_list_provider.dart` | Reactive local food list provider |
| `lib/core/database/database.dart` | AppDatabase with all DAO methods |

### Current Search Flow

```
CombinedLogScreen (FAB tap)
  └─ showSearch(FoodSearchDelegate)
       ├─ Toggle: "My Foods" / "Search the Web"
       │
       ├─ My Foods mode:
       │    └─ localFoodListProvider(query) → FoodSearchService.searchLocal()
       │         └─ db.searchLocalByRecency() → ordered by recency, then alpha
       │         └─ ListTile: tap → onQuickLog(item) → QuickFoodLogSheet
       │              └─ db.insertEntry() with scaled macros
       │              └─ dataTriggerProvider++ → reactive refresh
       │
       ├─ Search the Web mode:
       │    └─ FoodSearchService.searchWeb(query)
       │         └─ OpenFoodFactsClient.search(query)
       │         └─ FoodSearchItem.fromFoodResult() (calorie clamping applied)
       │         └─ ListTile: tap → onSelectItem(item) → close(delegate, item)
       │              └─ CombinedLogScreen._onSearch: _showQuickLogSheet(result)
       │                   └─ Same QuickFoodLogSheet flow (saves to DB if web food)
       │
       └─ Create custom food (ListTile at top of local list):
            └─ onCreateCustomFood(context) → Navigator.push(ManualFoodForm)
                 └─ Save: db.insertFood(source='manual') → pop(Food)
                      └─ delegate pops with result → QuickFoodLogSheet opens
```

---

## Implementation Plans

### Issue 1: Display brand in food search + editable brand in custom food form

#### 1A. Display brand in search results

**File**: `lib/features/logging/widgets/food_search_delegate.dart`

**Changes**:
- In `_LocalSearchContent._buildList()` (line ~262), modify the subtitle:
  ```dart
  // Current:
  subtitle: Text('$macroText\n${item.servingLabel}'),

  // New:
  final brandLine = item.brand != null && item.brand!.isNotEmpty
      ? '${item.brand} • ${item.servingLabel}'
      : item.servingLabel;
  subtitle: Text('$macroText\n$brandLine'),
  ```
- Apply the same change to `_WebSearchContent` ListView (line ~430).

**Risk**: None. Purely additive. The `brand` field is already populated on `FoodSearchItem` from both `Food` and `FoodResult`.

#### 1B. Add brand field to ManualFoodForm

**File**: `lib/features/logging/widgets/manual_food_form.dart`

**Changes**:
- Add `_brandController = TextEditingController()` field
- In `initState()`, pre-fill from `widget.existingFood?.brand`
- Add `TextFormField` for brand between Name and Quantity/Unit row:
  - Label: "Brand (optional)"
  - No validator (optional field)
  - `onChanged: (_) => setState(() {})` to trigger rebuilds
- In `_save()`, include brand in both insert and update paths:
  ```dart
  final brand = _brandController.text.trim();
  // ...
  brand: Value(brand.isEmpty ? null : brand),
  ```
- In the `Food` objects returned via `Navigator.pop()`, include the brand value.

**Risk**: Low. The `brand` column already exists in the schema. The `FoodsCompanion` already supports it.

#### Tests

- `test/features/logging/manual_food_form_test.dart`: Add test verifying brand field is present, pre-fills on edit, and saves correctly.
- `test/features/logging/search_delegate_test.dart`: Add test verifying brand text appears in local food ListTiles when brand is set.

---

### Issue 2: Web search tap → open custom food form, return to search

**File**: `lib/features/logging/widgets/food_search_delegate.dart`

**Current behavior**: `_WebSearchContent` ListView tap → `widget.onSelectItem(item)` → `close(context, item)` → caller receives item → opens `QuickFoodLogSheet` → logs immediately.

**New behavior**: Tap web result → open `ManualFoodForm` pre-filled with the web food's data → user edits/saves → form returns to search delegate (stays open) → food now appears in "My Foods" list for manual logging.

**Changes**:

1. Pass `onCreateCustomFood` callback down to `_WebSearchContent`:
   - Add `onCreateCustomFood` parameter to `_WebSearchContent`
   - Wire it in `buildResults`/`buildSuggestions`

2. Modify `_WebSearchContent` ListView `onTap`:
   ```dart
   onTap: () async {
     // Build synthetic Food from FoodSearchItem for pre-filling the form
     final syntheticFood = Food(
       id: -1, // sentinel — triggers insert path in ManualFoodForm
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
     // Open form — do NOT close the search delegate
     await widget.onCreateCustomFoodForWeb(context, syntheticFood);
     // After form closes, refresh the local food list via dataTriggerProvider
     // so the newly saved food appears in "My Foods"
   },
   ```

3. Add new callback `onCreateCustomFoodForWeb` to `_FoodSearchContent` and `_WebSearchContent`:
   - Signature: `Future<void> Function(BuildContext, Food)`
   - Opens `ManualFoodForm(existingFood: syntheticFood)` without closing the delegate
   - On save, increments `dataTriggerProvider` to refresh the local food list

4. Wire in `buildResults`/`buildSuggestions`:
   ```dart
   onCreateCustomFoodForWeb: (ctx, food) async {
     await Navigator.of(ctx).push<Food>(
       MaterialPageRoute(builder: (_) => ManualFoodForm(existingFood: food)),
     );
     ref.read(dataTriggerProvider.notifier).state++;
   },
   ```

**Key design decisions**:
- Using `id: -1` as sentinel works because `ManualFoodForm` checks `widget.existingFood != null` to decide pre-fill vs blank, and then checks `widget.existingFood!.id` to decide update vs insert. Since `-1` won't match any real DB row, `updateFoodById` would fail — but actually, looking at the code, `ManualFoodForm._save()` calls `db.updateFoodById(widget.existingFood!.id, ...)` when `existingFood != null`. This would try to update row -1, which would affect 0 rows, then the form would pop the food. The food would NOT be saved to the database.

  **Fix needed**: `ManualFoodForm._save()` needs to distinguish between "editing a real food" and "pre-filling from a web result." Options:
  - **Option A**: Add `isFromWebImport` flag to `ManualFoodForm`. When true, always use insert path.
  - **Option B**: Use `id <= 0` as the signal to use insert path. Simple, no new parameter.
  - **Option C (Recommended)**: In `ManualFoodForm._save()`, check if `widget.existingFood!.id` exists in the database before deciding update vs insert. If not found, use insert. This is the most robust.

  **Actually**, the simplest approach: `ManualFoodForm` already has the logic — `if (widget.existingFood != null)` → update, else → insert. We just need to change the condition to also check if the food has a real ID. Changing to `if (widget.existingFood != null && widget.existingFood!.id > 0)` would handle both cases: real edits (id > 0) use update, web pre-fills (id = -1) use insert.

**Risk**: Medium. Changes the web search tap flow. Need to ensure:
- Barcode scanner path still works (it uses `onQuickLog` directly, not affected)
- Recipe form path still works (it uses `onSelectItem` as fallback when `onQuickLog` is null — web items in recipe form context should still return the item)
- The `dataTriggerProvider` increment properly refreshes `localFoodListProvider`

**Tests**:
- `test/features/logging/search_delegate_test.dart`: Add test verifying tapping a web result opens `ManualFoodForm`, and after save the delegate remains open.

---

### Issue 3: Sorting — recently imported (unlogged) > recently logged > alphabetical

**File**: `lib/core/database/database.dart` — `searchLocalByRecency()` method (lines 204-241)

**Current algorithm**:
1. Fetch all `food_entries` ordered by `loggedAt DESC`
2. Deduplicate food IDs, preserving first-seen order (most recent first)
3. Append never-logged foods sorted alphabetically
4. Filter by query if provided, take limit

**New algorithm** (per user clarification):

Three groups with strict precedence:

| Group | Criteria | Sort |
|-------|----------|------|
| **A: Recently imported** | `source == 'open_food_facts'` AND **never logged** (no entry in `food_entries`) | `createdAt DESC` (most recent import first) |
| **B: Recently logged** | Has at least one `food_entry` (any source) | `MAX(loggedAt) DESC` (most recent log first) |
| **C: Never logged, not imported** | `source != 'open_food_facts'` AND never logged | `name ASC` (alphabetical) |

**Implementation**:

```dart
Future<List<Food>> searchLocalByRecency({String? query, int limit = 50}) async {
  // Step 1: Build lastLoggedAt map from food_entries
  final allEntries = await (select(foodEntries)
        ..where((f) => f.foodId.isNotNull())
        ..orderBy([(f) => OrderingTerm(expression: f.loggedAt, mode: OrderingMode.desc)]))
      .get();

  final lastLoggedAt = <int, String>{};
  final loggedFoodIds = <int>{};
  for (final entry in allEntries) {
    if (entry.foodId != null && !loggedFoodIds.contains(entry.foodId!)) {
      loggedFoodIds.add(entry.foodId!);
      lastLoggedAt[entry.foodId!] = entry.loggedAt;
    }
  }

  // Step 2: Fetch all foods
  final allFoods = await select(foods).get();

  // Step 3: Partition into three groups
  final groupA = <Food>[]; // Recently imported, never logged
  final groupB = <Food>[]; // Recently logged
  final groupC = <Food>[]; // Never logged, not imported

  for (final food in allFoods) {
    if (loggedFoodIds.contains(food.id)) {
      groupB.add(food);
    } else if (food.source == 'open_food_facts') {
      groupA.add(food);
    } else {
      groupC.add(food);
    }
  }

  // Step 4: Sort each group
  groupA.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // DESC
  groupB.sort((a, b) {
    final aTime = lastLoggedAt[a.id] ?? '';
    final bTime = lastLoggedAt[b.id] ?? '';
    return bTime.compareTo(aTime); // DESC
  });
  groupC.sort((a, b) => a.name.compareTo(b.name)); // ASC

  // Step 5: Concatenate
  final combined = [...groupA, ...groupB, ...groupC];

  // Step 6: Filter and limit
  if (query != null && query.trim().isNotEmpty) {
    final q = query.toLowerCase();
    return combined.where((f) => f.name.toLowerCase().contains(q)).take(limit).toList();
  }
  return combined.take(limit).toList();
}
```

**Edge cases**:
- **OFF food that was imported, then logged**: Goes to group B (recently logged), not group A. Correct per user spec.
- **OFF food imported but never logged**: Goes to group A. Shows above all logged foods.
- **Manual food never logged**: Goes to group C. At the bottom, alphabetical.
- **Manual food that was logged**: Goes to group B. Sorted by recency.
- **Empty database**: Returns empty list.
- **Query filter**: Applied after grouping/sorting, so results maintain group precedence within the filtered set.

**Performance note**: Current implementation fetches ALL `food_entries` and ALL `foods` into Dart memory. For a typical user with hundreds of foods and thousands of entries, this is fine. If the database grows very large, we could optimize with SQL queries, but drift 2.31.0 doesn't support `GROUP BY` on `SimpleSelectStatement`, so the Dart-side loop is necessary anyway.

**Tests**:
- `test/providers/food_search_provider_test.dart`: Update the `searchLocal returns foods sorted by recency` test:
  - Insert an OFF-imported food (never logged) — should appear first
  - Insert and log manual foods — should appear after imported
  - Insert a manual food never logged — should appear last (alphabetical)
  - Log the imported food — it should move from group A to group B

---

## Implementation Order

1. **Issue 3** (sorting) — Backend change, no UI risk, tests are straightforward
2. **Issue 1** (brand display + editable field) — Additive UI change, low risk
3. **Issue 2** (web tap → form) — Most complex, changes user flow

## Risk Assessment

| Issue | Risk | Notes |
|-------|------|-------|
| 1: Brand display | Low | Purely additive. Brand field already exists in schema and models. |
| 1: Brand editable | Low | `FoodsCompanion` already supports brand. Form is well-tested. |
| 2: Web tap flow | Medium | Changes user flow. Must verify barcode scanner and recipe form paths are unaffected. |
| 3: Sorting | Low-Medium | Changes algorithm but not data integrity. `createdAt` is reliably set for OFF imports via `saveApiResult()`. |

## Dependencies Between Issues

- Issue 2 depends on Issue 1 only in that the `ManualFoodForm` will have the brand field (from Issue 1), so pre-filled web foods will show the brand. These can be implemented independently.
- Issue 3 is fully independent.

## Files to Modify

| File | Issues |
|------|--------|
| `lib/core/database/database.dart` | 3 |
| `lib/features/logging/widgets/food_search_delegate.dart` | 1, 2 |
| `lib/features/logging/widgets/manual_food_form.dart` | 1 |

## Tests to Add/Modify

| Test File | Changes |
|-----------|---------|
| `test/providers/food_search_provider_test.dart` | Update sorting test for Issue 3 |
| `test/features/logging/search_delegate_test.dart` | Add brand display test (Issue 1), add web tap → form test (Issue 2) |
| `test/features/logging/manual_food_form_test.dart` | Add brand field test (Issue 1) |
