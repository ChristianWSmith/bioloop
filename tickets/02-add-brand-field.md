# Ticket 02 — Add brand field to foods table

**Issues**: #11  
**Phase**: 1  
**Dependencies**: None  
**Estimate**: ~1 hour

---

## Context

The `foods` table has no `brand` column. OpenFoodFacts API responses include
a `brands` field (comma-separated string), but it is currently discarded when
parsing `FoodResult`. Users need brand info to distinguish between similar
products.

---

## Acceptance Criteria

1. `foods` table has an optional `brand TEXT` column (nullable).
2. Schema version is 4 (migration from v3 adds the column).
3. `FoodResult.fromJson()` parses `brands` from the API response.
4. `FoodSearchItem` carries the brand field.
5. All `FoodsCompanion.insert()` call sites pass brand.
6. Newly scanned/searched foods from OpenFoodFacts show the brand.
7. Existing foods have `brand = null` (backward compatible).

---

## Implementation

### 1. Table definition
**File**: `lib/core/database/tables/foods.dart`

Add after line 15 (after `barcode`):
```dart
TextColumn get brand => text().nullable()();
```

### 2. Schema migration
**File**: `lib/core/database/database.dart`

- Bump `schemaVersion` to 4 (line 29).
- In `onUpgrade`, add:
  ```dart
  if (from < 4) {
    await m.addColumn(foods, foods.brand);
  }
  ```

### 3. API model
**File**: `lib/core/api/models/food_result.dart`

- Add `String? brand` field to `FoodResult`.
- In `FoodResult.fromJson()`, parse `json['brands'] as String?` (note: the
  API key is `brands`).

### 4. Search model
**File**: `lib/providers/food_search_provider.dart`

- Add `String? brand` to `FoodSearchItem`.
- `fromFood()`: map `food.brand`.
- `fromFoodResult()`: map `result.brand`.

### 5. All insert call sites
Every `FoodsCompanion.insert()` call needs `brand: Value(...)`. There are 4:

| Call site | File | Value |
|-----------|------|-------|
| API save (main log) | `log_food_screen.dart:162` | `Value(food.brand)` |
| API save (quick-log) | `quick_food_log_sheet.dart:63` | `Value(food.brand)` |
| Custom food (manual) | `manual_food_form.dart:126` | `const Value(null)` |
| API save (search svc) | `food_search_provider.dart:97` | `Value(item.brand)` |

### 6. Recipe form screen
**File**: `lib/features/recipes/recipe_form_screen.dart:125`

The `Food(...)` constructor in `_addIngredient()` (line 115-128) constructs a
`Food` object — needs `brand: food.brand` added.

---

## Testing

### Unit tests
- **`test/database_test.dart`**: Add test that foods table has `brand` column,
  that inserting a food with brand reads back correctly, that existing foods
  have `brand = null`.
- **`test/api/open_food_facts_client_test.dart`**: Update mock API JSON to
  include `"brands": "Nike"` and verify `FoodResult.brand` is parsed.

### Manual tests
- Scan a barcode for a known brand product (e.g. "Coca-Cola")
- **Verify**: The food search item shows brand in the display
- **Verify**: After saving, the food's brand is persisted (restart app, open
  food list, see brand)
- **Verify**: Custom foods created via ManualFoodForm have `null` brand
- **Verify**: Editing an existing food (e.g. changing servings) doesn't clear
  brand (null-safe)

---

## Files Changed

| File | Change |
|------|--------|
| `lib/core/database/tables/foods.dart` | Add `brand` column |
| `lib/core/database/database.dart` | Schema v4, add migration |
| `lib/core/api/models/food_result.dart` | Add `brand` field, parse `brands` |
| `lib/providers/food_search_provider.dart` | Add `brand` to `FoodSearchItem` |
| `lib/features/logging/log_food_screen.dart` | Pass brand in `FoodsCompanion` |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | Pass brand |
| `lib/features/logging/widgets/manual_food_form.dart` | Pass `Value(null)` |
| `lib/features/recipes/recipe_form_screen.dart` | Pass brand to `Food` ctor |

---

## Open Questions

- Should brand be displayed in the search results list, or just used
  internally for sorting/filtering? The ticket only covers storage.
  Display can be a follow-up.
- `brands` is comma-separated in the API (e.g. "Nestlé, Purina"). Store as-is
  or take first brand only? Recommendation: store as-is for now.
