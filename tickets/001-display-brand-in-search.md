# Ticket 1: Display brand in food search results

## Status
- [ ] Not started

## Scope
`lib/features/logging/widgets/food_search_delegate.dart`

## Context
The `foods` table has a `brand` column that is populated from OpenFoodFacts API results (`json['brands']`) and is available on `FoodSearchItem`. However, it is never displayed in the UI. Users cannot see the brand of foods in either "My Foods" or "Search the Web" views.

## Requirements
- In `_LocalSearchContent._buildList()`, add brand to the ListTile subtitle when present
- In `_WebSearchContent` ListView, add brand to the ListTile subtitle when present
- Format: `"{brand} • {servingLabel}"` when brand is non-null and non-empty
- Format: `"{servingLabel}"` when brand is null or empty (current behavior)
- Brand should appear on the second line of the subtitle, after the macro text

## Acceptance Criteria
- [ ] Local food ListTiles show brand when `item.brand` is set
- [ ] Web search ListTiles show brand when `item.brand` is set
- [ ] Foods without brand display unchanged (no extra bullet or whitespace)
- [ ] `flutter analyze` passes with zero issues

## Testing
- **Widget test** (`test/features/logging/search_delegate_test.dart`):
  - Insert a food with brand set, verify brand text appears in the ListTile subtitle
  - Insert a food without brand, verify subtitle shows only servingLabel
  - Search web for a product with brand, verify brand appears in web results ListTiles

## Files to Modify
- `lib/features/logging/widgets/food_search_delegate.dart`

## Notes
- `FoodSearchItem.brand` is already populated from both `Food` and `FoodResult`
- No database changes needed
- No changes to `FoodSearchService` or providers needed
