# T3 — OpenFoodFacts API client

HTTP client for the OpenFoodFacts API.

## Files to create

- `lib/core/api/open_food_facts_client.dart` — `OpenFoodFactsClient` class
- `lib/core/api/models/food_result.dart` — deserialized API response model

## API endpoints

- `GET https://world.openfoodfacts.org/cgi/search.pl?search_terms={query}&json=true&page_size=25`
- `GET https://world.openfoodfacts.org/api/v2/product/{barcode}.json`

## Fields to extract per product

| API field | Our field |
|-----------|-----------|
| `product.product_name` | `name` |
| `product.serving_size` | `servingLabel` |
| `product.nutriments["energy-kcal_serving"]` | `caloriesPerServing` |
| `product.nutriments["proteins_serving"]` | `proteinPerServing` |
| `product.nutriments["carbohydrates_serving"]` | `carbsPerServing` |
| `product.nutriments["fat_serving"]` | `fatPerServing` |
| `product.nutriments["energy-kcal_100g"]` | fallback (× serving_size_grams / 100) |
| `product.code` | `barcode` |

If `_serving` fields are absent, compute from `_100g` fields assuming a 100g serving and set `servingLabel = "100g"`.

## Acceptance criteria

- `search("chicken breast")` returns parsed results within 5s
- `getByBarcode("3017620422003")` returns single product (Nutella)
- Handles HTTP errors, timeouts, and malformed JSON gracefully (returns empty results / null)
- Models are plain Dart classes with `fromJson`

## Dependencies

Add to `pubspec.yaml`:
- `http`

## Testing

- **Unit — search parsing**: inject a sample API JSON response, verify `search()` returns `List<FoodResult>` with correct field mapping
- **Unit — barcode parsing**: inject a product JSON, verify `getByBarcode()` returns correctly mapped `FoodResult`
- **Unit — `_serving` fallback**: inject a product JSON missing `_serving` fields but with `_100g` fields, verify it computes per-serving macros assuming 100g serving
- **Unit — empty results**: inject `{"products": []}`, verify returns empty list
- **Unit — malformed JSON**: inject garbage string, verify returns null / empty without throwing
- **Unit — HTTP 429**: inject 429 response, verify graceful handling (retry header or empty)
- **Unit — timeout**: inject `SocketException`, verify returns null / empty
- **Unit — model parity**: every field in `FoodResult` maps to a field in the drift `Food` table (same types, same semantics)

Use `MockClient` from `http` testing utilities to inject responses without network.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Real API call: `search("chicken breast")` returns results within 5s on device/emulator with network
- [ ] Real API call: `getByBarcode("3017620422003")` returns Nutella with correct serving data
- [ ] Fallback path: find a product without `_serving` fields in the API response and verify the `_100g` fallback works correctly
- [ ] All 8 unit tests pass with `MockClient` (no network dependency in tests)
- [ ] `FoodResult` model fields match `Food` table columns 1:1 — confirm no mapping gaps
- [ ] Error responses (404, 429, timeout) don't crash the app — verify in code review
- [ ] User-agent header is set (OpenFoodFacts may block requests without one)

## Notes

- OpenFoodFacts is rate-limited. No auth needed. Respect `429` responses.
- Base URL and user-agent should be configurable constants.

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T3 — OpenFoodFacts API client | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
