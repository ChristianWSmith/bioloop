# 010 — Add debouncing to food search

- **Phase**: 3 — Bug Fixes
- **Priority**: High

## Overview

Every keystroke in the food search field triggers a new API call to OpenFoodFacts. This is poor API etiquette (risks rate limiting) and causes the loading spinner to restart on each keypress, creating visual jitter. Add debouncing to only fire the search when the user has stopped typing for ~400ms.

## Context from Discovery

- `FoodSearchDelegate._buildContent()` (`lib/features/logging/widgets/food_search_delegate.dart:57–96`): uses `FutureBuilder` keyed with `ValueKey(query)`.
- Every character change creates a new `ValueKey` → abandons old Future → creates new one → calls `searchService.search(query)`.
- `search()` (`lib/providers/food_search_provider.dart:68–89`) first queries local DB (fast), then calls `apiClient.search()` (network, 10s timeout) if local results < 25.
- No debounce timer exists anywhere in the pipeline.
- Flutter's `SearchDelegate` calls `buildSuggestions` on each rebuild — rapid typing creates rapid cancellation/re-creation.

## Implementation Options

1. **Debounce in `FoodSearchDelegate`**: Add a `Timer?` in the delegate. Cancel on each `buildSuggestions`, start new 400ms timer. Only call `searchService.search()` when timer fires.
2. **Debounce in `FoodSearchService`**: Add a debounce wrapper in the provider layer.

Option 1 is preferred because the delegate is the right layer for UI-level input handling. However, `SearchDelegate`'s `buildSuggestions` is `Widget buildSuggestions(BuildContext context)` — it's a build method, not an event handler. We need to use `query` setter override or use `onQueryChanged` pattern.

Actually, `SearchDelegate` has `onQueryChanged(String query)` which we can override to debounce. Or we can debounce directly in `_buildContent` using a `StatefulWidget` wrapper.

Better approach: Since `FoodSearchDelegate` extends `SearchDelegate`, we can override `buildSuggestions` to return a debounced widget. Or, simpler: introduce a small stateful wrapper inside `_buildContent` that debounces the query before passing it to the `FutureBuilder`.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/logging/widgets/food_search_delegate.dart` | Add debounce timer (~400ms). Cancel previous timer on each `buildSuggestions` call. Only invoke `searchService.search()` after the delay. Ensure local DB queries are still immediate (debounce only the API call, or debounce the entire search — local DB is fast enough that it doesn't matter). |

## Acceptance Criteria

- [ ] Rapid typing does not trigger multiple API calls — only one fires after typing stops for 400ms
- [ ] Loading spinner does not restart on each keystroke
- [ ] Final search results are correct for the completed query
- [ ] Clear button works immediately (no debounce delay)
- [ ] No memory leaks (timer is cancelled on delegate close)
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Unit test: simulate rapid consecutive searches, verify only one API call is made after debounce period
- Unit test: verify timer is cancelled on delegate dispose
- Widget test: verify search still returns results (integration-level)
