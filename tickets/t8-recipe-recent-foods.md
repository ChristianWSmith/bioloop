# T8: Fix recipe ingredient search — recent foods not shown

## Status

| Field | Value |
|-------|-------|
| Priority | Medium |
| Complexity | Medium — needs debug, root cause unknown |
| Files changed | TBD after diagnosis |
| Risk | Medium — Riverpod context resolution may require architectural fix |

## Context

When adding an ingredient to a recipe, the ingredient search (`RecipeFormScreen._addIngredient()`) uses the same `FoodSearchDelegate` as the normal food search (`LogFoodScreen._onSearch()`). Both call `showSearch<FoodSearchItem?>(context: context, delegate: FoodSearchDelegate(...))`.

The delegate's `_RecentFoodsSection` (a `ConsumerWidget` watching `recentFoodsProvider`) renders unconditionally when `query.isEmpty` at `food_search_delegate.dart:51`. There is no code-level difference in how the delegate is configured that would suppress recent foods.

**Confirmed on-device:** Recent foods do NOT appear in the recipe ingredient search, even though they appear correctly in the normal food search.

**Likely cause:** Riverpod context resolution inside `showSearch`. When called from `RecipeFormScreen` (a pushed route), the `showSearch` overlay route's widget tree may not have a `ProviderScope` ancestor. This would cause the `ConsumerWidget._RecentFoodsSection` to fail silently or throw.

**Other possibilities:**
- Nested Navigator interaction (if `RecipeFormScreen` is inside a tab Navigator)
- `showSearch` creating a route whose build context is outside the `ProviderScope`
- Silent error in `recentFoodsProvider` within the overlay context (renders "Could not load recent foods" text — easy to miss)

## Intent

Make recent foods appear in the recipe ingredient search, matching the normal food search behavior.

## Investigation needed

### Step 1: Reproduce in a controlled test

Write a widget test that:
1. Pushes a `RecipeFormScreen` onto a test Navigator wrapped in `ProviderScope`
2. Inserts seed food entries into the in-memory DB
3. Taps "Add ingredient" → `showSearch` opens
4. Asserts `_RecentFoodsSection` renders with seeded items

If the test fails (recent foods don't appear), the bug is reproducible in test and we can debug from there.

### Step 2: If reproducible — diagnose

- Check whether `ref.watch(recentFoodsProvider)` inside `_RecentFoodsSection.build()` throws or returns error state when called from the `showSearch` context
- Wrap `_RecentFoodsSection` in a `ProviderScope` with explicit overrides if needed
- Alternatively, pre-fetch recent foods in `RecipeFormScreen` and pass them to the delegate

### Step 3: Fix

Possible fixes (choose based on diagnosis):

| Approach | Trade-off |
|----------|-----------|
| **A:** Wrap `_buildContent`'s child in `ProviderScope` with `databaseProvider` override | Explicit, works regardless of context chain |
| **B:** Pre-fetch recent foods in `RecipeFormScreen`, pass as param to `FoodSearchDelegate` | Avoids Riverpod dependency in overlay; more explicit but adds prop drilling |
| **C:** Ensure `showSearch` context is from within `ProviderScope` at app root | May require restructuring `_AppShell` or how routes are pushed |

## Testing

- Widget test: ingredient search shows recent foods from seed data
- Widget test: selecting a recent food in ingredient search opens quantity dialog
- All existing tests continue to pass

## Dependencies

None. Independent of T6 and T7.
