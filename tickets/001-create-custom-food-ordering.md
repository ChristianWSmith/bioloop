# T1: Fix "Create custom food" ordering

**Issue:** #6
**Effort:** ~2 min
**Dependencies:** None

## Context

In `FoodSearchDelegate._buildContent()` (`lib/features/logging/widgets/food_search_delegate.dart`), the "Create custom food" `ListTile` currently appears **after** the "Recent Foods" section when the query is empty. The user expects it to appear **before** recent foods on all food search screens.

Current order when query is empty:
1. _RecentFoodsSection
2. "Create custom food" ListTile

Desired order:
1. "Create custom food" ListTile
2. _RecentFoodsSection

When the user types a query, recent foods disappear and only "Create custom food" + search results are shown — that behaviour is correct and unchanged.

## Intent

Make "Create custom food" the first actionable item in the search delegate so users can always find it immediately without scrolling past recent foods.

## Changes

**File:** `lib/features/logging/widgets/food_search_delegate.dart`

In `_buildContent()`, swap the positions of the `_RecentFoodsSection` and the "Create custom food" `ListTile`. The `if (query.isEmpty)` guard stays on `_RecentFoodsSection` only — "Create custom food" must remain unconditional (always shown).

## Testing

- **Manual:** Open any food search screen (log tab search, recipe ingredient search). With no query typed, verify "Create custom food" appears first, then recent foods below it. Type a query and verify "Create custom food" still appears at the top before search results.
- **Widget test:** `FoodSearchDelegate` could have a test that verifies tile ordering in `_buildContent` for both empty and non-empty queries.
