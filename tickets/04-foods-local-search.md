# T4 — Foods reference table + local search

DAO for the `foods` table, local search provider, and auto-caching of API results.

## Files to create

- `lib/providers/food_search_provider.dart` — `FoodSearchProvider` (Riverpod)

## Files to modify

- `lib/core/database/tables/foods.dart` — add DAO methods

## DAO methods needed

- `Future<int> insertFood(Food food)` — returns id
- `Future<Food?> getByBarcode(String barcode)`
- `Future<List<Food>> searchByName(String query, {int limit = 25})` — `LIKE '%query%'` on `name`
- `Future<void> upsertFood(Food food)` — insert or update by barcode

## Provider behavior

`FoodSearchProvider` takes a query string:
1. Query local `foods` table (instant)
2. If fewer than 25 results, also query OpenFoodFacts API (from T3)
3. Merge: local results first, API results appended, deduplicated by barcode
4. Auto-save API results to `foods` table when user selects them (not on search — only on selection, to keep cache clean)

## Acceptance criteria

- `searchByName("apple")` returns local foods matching "apple"
- Provider merges local + API results correctly, no duplicate barcodes
- Selecting an API result triggers `insertFood` into `foods`
- Re-running the same search returns the cached result instantly

## Dependencies

T1 (database), T3 (API client)
