# Ticket 06: Add retry tap to "No results found" in web search

**Category:** OpenFoodFacts API
**Status:** Pending
**Depends on:** Ticket 05
**Blocks:** None

## Problem

In the web search content, "No results found" is displayed as static text with no way to retry. This is inconsistent with the "Search failed. Tap to retry." message which uses a `GestureDetector` + `_retryTrigger` pattern.

## Context

- `lib/features/logging/widgets/food_search_delegate.dart:420-425` — current static "No results found" text
- `lib/features/logging/widgets/food_search_delegate.dart:410-417` — existing "Search failed. Tap to retry." with `GestureDetector` and `_retryTrigger`
- `lib/features/logging/widgets/food_search_delegate.dart:356` — `_retryTrigger` field already exists in `_WebSearchContentState`
- `lib/features/logging/widgets/food_search_delegate.dart:399` — `ValueKey('$_debouncedQuery-$_retryTrigger')` on FutureBuilder

## Changes Required

Replace the static "No results found" text with a tappable retry:

```dart
// Before (lines 420-425):
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('No results found'),
),

// After:
GestureDetector(
  onTap: () => setState(() => _retryTrigger++),
  child: const Padding(
    padding: EdgeInsets.all(16),
    child: Text('No results found. Tap to retry.'),
  ),
),
```

The `_retryTrigger` increment causes the FutureBuilder's `ValueKey` to change, which re-runs the search.

## Acceptance Criteria

- [ ] "No results found" text is tappable and re-triggers the API search
- [ ] Text reads "No results found. Tap to retry."
- [ ] Visual styling matches the existing "Search failed. Tap to retry." pattern
- [ ] After tapping retry, if results appear, they are displayed in a ListView
- [ ] After tapping retry, if still no results, the same tappable message is shown

## Testing

- Widget test: search returns empty → "No results found. Tap to retry." is visible
- Widget test: tap the retry text → new search is triggered (FutureBuilder re-runs)
- Widget test: tap retry → mock returns results → ListView with items is displayed

## Files Affected

- `lib/features/logging/widgets/food_search_delegate.dart` — replace static text with GestureDetector
- `test/features/logging/search_delegate_test.dart` — update/add tests for retry behavior
