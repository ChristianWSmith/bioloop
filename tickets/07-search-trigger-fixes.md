# Ticket 07: Fix search trigger behavior (focus, Enter, toggle)

**Category:** OpenFoodFacts API
**Status:** Pending
**Depends on:** None
**Blocks:** None

## Problem

Three issues with how searches are triggered in `_WebSearchContent`:

1. **Search fires on focus with stale query:** When the search delegate opens, `buildSuggestions` is called immediately. If `query` is non-empty from a previous search session, the debounce timer starts and triggers a search after 400ms. The issue says searches should only trigger on edit, not on focus.

2. **Duplicate search on Enter during in-flight request:** Pressing Enter calls `buildResults`, which creates a new `_FoodSearchContent` → new `_WebSearchContent` → new FutureBuilder. If a previous search is still in-flight, this creates a duplicate HTTP request.

3. **Toggle to "Search the Web" doesn't trigger search:** When toggling from "My Foods" to "Search the Web" with text already in the search bar, the web search shows "Enter a search term" because `_debouncedQuery` is empty until the debounce fires. The issue says we SHOULD launch a search in this case.

## Context

- `lib/features/logging/widgets/food_search_delegate.dart:354-386` — debounce logic (`_debounceTimer`, `_startDebounce`)
- `lib/features/logging/widgets/food_search_delegate.dart:359-361` — `_startDebounce()` called in `initState()`
- `lib/features/logging/widgets/food_search_delegate.dart:365-370` — restarts debounce in `didUpdateWidget` when query changes
- `lib/features/logging/widgets/food_search_delegate.dart:398-446` — FutureBuilder with `ValueKey`
- `lib/features/logging/widgets/food_search_delegate.dart:170-173` — toggle `onSelectionChanged` handler

## Changes Required

### Fix 1: Prevent focus-triggered search

Add a `_hasUserEdited` boolean flag in `_WebSearchContentState`:

- Initialize to `false` in `initState()`
- In `didUpdateWidget`, set `_hasUserEdited = true` only when `widget.query != oldWidget.query` AND the widget was already mounted (meaning the user actually typed, not just initial mount)
- In `_startDebounce()`, only set `_debouncedQuery` if `_hasUserEdited` is true
- If `_hasUserEdited` is false and query is non-empty, set `_debouncedQuery = ''` (don't search)

### Fix 2: Prevent duplicate Enter searches

Add an `_isSearching` boolean in `_WebSearchContentState`:

- Set `_isSearching = true` when the FutureBuilder's future starts (use a `Future.doThen` wrapper or a state setter in the future chain)
- Set `_isSearching = false` when the future completes
- In `didUpdateWidget`, if `_isSearching` is true, don't restart the debounce timer

### Fix 3: Trigger search on mode toggle

In `_FoodSearchContentState`'s `onSelectionChanged` handler (lines 170-173):

- When switching to `'web'` and `widget.query.isNotEmpty`, pass the query as an "immediate query" to `_WebSearchContent`
- `_WebSearchContent` accepts an optional `String? immediateQuery` parameter
- If `immediateQuery` is non-null, set `_debouncedQuery = immediateQuery` immediately in `initState()`, bypassing debounce

## Acceptance Criteria

- [ ] Opening search with a stale query does NOT trigger an API call
- [ ] Typing a query DOES trigger a debounced search (400ms)
- [ ] Pressing Enter while search is in-flight does NOT launch a duplicate request
- [ ] Toggling to "Search the Web" with text in the field immediately triggers a search (no debounce wait)
- [ ] Toggling to "Search the Web" with empty field shows "Enter a search term"
- [ ] `flutter analyze` passes with zero issues

## Testing

Update `test/features/logging/search_delegate_test.dart`:

- Test: open search → type "chicken" → press Enter → toggle to "Search the Web" → search triggers immediately (no debounce wait)
- Test: open search with stale query → no API call is made until user types
- Test: type query → press Enter → immediately press Enter again → only one API call is made
- Test: toggle to "Search the Web" with empty query → "Enter a search term" is shown

## Files Affected

- `lib/features/logging/widgets/food_search_delegate.dart` — add `_hasUserEdited`, `_isSearching`, `immediateQuery`
- `test/features/logging/search_delegate_test.dart` — update/add tests
