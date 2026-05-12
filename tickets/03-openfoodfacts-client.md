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

## Notes

- OpenFoodFacts is rate-limited. No auth needed. Respect `429` responses.
- Base URL and user-agent should be configurable constants.
