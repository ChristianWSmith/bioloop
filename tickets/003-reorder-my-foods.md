# Ticket 3: Reorder "My Foods" — imported (unlogged) > logged > alphabetical

## Status
- [ ] Not started

## Scope
`lib/core/database/database.dart` — `searchLocalByRecency()` method

## Context
Currently, "My Foods" sorts all foods by last log date (most recent first), with never-logged foods appended alphabetically. Users who import foods from OpenFoodFacts want those recently imported foods to appear at the top, above even recently logged foods. Once an imported food is logged, it should lose its "recently imported" status and fall into the normal recency order.

## Current Algorithm
1. Fetch all `food_entries` ordered by `loggedAt DESC`
2. Deduplicate food IDs, preserving first-seen order
3. Append never-logged foods sorted alphabetically
4. Filter by query, take limit

## New Algorithm
Partition foods into three groups with strict precedence:

| Group | Criteria | Sort |
|-------|----------|------|
| **A: Recently imported** | `source == 'open_food_facts'` AND **never logged** | `createdAt DESC` |
| **B: Recently logged** | Has ≥1 `food_entry` (any source) | `MAX(loggedAt) DESC` |
| **C: Never logged, not imported** | `source != 'open_food_facts'` AND never logged | `name ASC` |

Final order: A + B + C, then apply query filter and limit.

## Acceptance Criteria
- [ ] OFF-imported foods that have never been logged appear at the top
- [ ] Among imported foods, most recently imported appears first
- [ ] All logged foods appear after imported foods, sorted by most recent log
- [ ] Never-logged manual foods appear at the bottom, alphabetically
- [ ] After logging an imported food, it moves from group A to group B
- [ ] Query filter works correctly across all three groups
- [ ] `flutter analyze` passes with zero issues
- [ ] `flutter test` passes with zero failures

## Testing
- **Unit test** (`test/providers/food_search_provider_test.dart`):
  - Insert OFF-imported food (never logged), manual logged food, manual unlogged food
  - Verify order: imported → logged → alphabetical
  - Log the imported food → verify it moves to the logged group
  - Test query filtering preserves group precedence

## Files to Modify
- `lib/core/database/database.dart`

## Notes
- `createdAt` is reliably set for OFF imports via `FoodSearchService.saveApiResult()` → `DateTime.now().toIso8601String()`
- Current implementation already fetches all entries and foods into Dart memory (drift 2.31.0 has no `GROUP BY`), so the new algorithm fits the existing pattern
- Performance is fine for typical user databases (hundreds of foods, thousands of entries)
