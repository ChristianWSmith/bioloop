# 013 — Investigate "white rice" OpenFoodFacts search failure

- **Phase**: 4 — Polish
- **Priority**: Low

## Overview

Searching for "white rice" returns no results. This may be a limitation of the OpenFoodFacts API or how we're querying it. Investigate the API parameters and determine if we can improve the search results.

## Context from Discovery

- API endpoint: `GET https://world.openfoodfacts.org/cgi/search.pl?search_terms=<query>&json=true&page_size=25`
- `OpenFoodFactsClient.search()` (`lib/core/api/open_food_facts_client.dart:17–53`):
  - 10-second timeout
  - Returns empty list on 429 (rate limited), non-200, socket/HTTP/format exceptions
  - No additional search parameters beyond `search_terms` and `page_size`
- `FoodResult.fromJson()` parses OpenFoodFacts JSON, falling back from serving to 100g nutrition data.

## Investigation Steps

1. **Test the API directly**: Fetch `https://world.openfoodfacts.org/cgi/search.pl?search_terms=white+rice&json=true&page_size=25` in a browser or via curl to see what it returns.
2. **Check if alternative parameters help**: OpenFoodFacts supports `search_simple=1`, `action=process`, `fields` for selecting specific fields, `tagtype_0`/`tag_0` for categories. Maybe we need `search_simple=1` for broader matches.
3. **Try API v2**: Use `https://world.openfoodfacts.org/api/v2/search?search_terms=white+rice` which may have different behavior.
4. **Check language/locale**: The API might filter by locale. Try adding `lc=en` parameter.
5. **Check rate limiting**: If we've been testing heavily, we might be getting 429 responses silently (handled gracefully but returning empty).

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/api/open_food_facts_client.dart` | May need parameter adjustments based on investigation findings |

## Acceptance Criteria

- [ ] Root cause of "white rice" returning no results is identified
- [ ] If fixable: search returns results for "white rice" (and similar common foods)
- [ ] If not fixable: document as known limitation in code comment or AGENTS.md
- [ ] All changes pass `flutter analyze`
- [ ] Existing tests pass

## Testing

- Manual: run API queries directly and verify response
- Unit test: mock API response and verify parsing still works with any parameter changes
- No regression in existing food search tests
