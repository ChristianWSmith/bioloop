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

## Testing

- **Unit — DAO insert + search**: insert 3 foods, `searchByName("app")` returns foods with "apple" and "pineapple" but not "banana"
- **Unit — DAO upsert by barcode**: insert a food with barcode "X", upsert same barcode with different name, verify name updated and id unchanged
- **Unit — DAO getByBarcode**: returns `null` for unknown barcode
- **Unit — provider dedup**: mock API returns 3 results, 1 matches barcode in local DB, final list has no duplicate barcodes with local result first
- **Unit — provider auto-save**: selecting an API result calls `insertFood` (verify via spy/mock on DAO)
- **Unit — provider local-first**: when local search returns ≥25 results, API is not called

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] `FoodSearchProvider` correctly merges local + API results — manually test on emulator with network
- [ ] No duplicate barcodes in merged results — run a search where API returns a food already in local DB
- [ ] `LIKE` search is case-insensitive (ASCII only; accented chars like "café" won't match "cafe") — acceptable for MVP
- [ ] When local search returns ≥25 results, no API call is made (saves network + rate limit)
- [ ] Selecting an API result inserts it into `foods` — verify via DB inspection
- [ ] All 6 unit tests pass
- [ ] Search handles empty query gracefully (returns empty list, no API call)

## Dependencies

T1 (database), T3 (API client)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T4 — Foods reference table + local search | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
