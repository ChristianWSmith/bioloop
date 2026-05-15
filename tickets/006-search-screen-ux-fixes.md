# 006 — Fix search screen UX issues

**Issues**: #5, #8, #9
**Files**: `lib/features/logging/widgets/food_search_delegate.dart`, `lib/features/logging/combined_log_screen.dart`
**Effort**: Medium

---

## Context

Three UX issues on the food search screen:

### #9 — Re-log should return to log screen (definite fix)

**Root cause confirmed**: When the user taps the `+` quick-log icon on a food in the search results, the `onQuickLog` callback opens `QuickFoodLogSheet` but does **not** close the `showSearch` delegate. After the sheet closes, the user is still looking at the search results and must manually dismiss the search.

The tap-to-select path (tapping the food name) works correctly: it calls `close(context, item)`, the search resolves, and then the sheet opens.

### #5 — Search web toggle off-center (needs reproduction)

The `SegmentedButton` for "My Foods" / "Search the Web" appears to shift left when toggling to web mode. This needs to be reproduced and diagnosed with a running app.

### #8 — Web search failure flips to "My Foods" (needs reproduction)

When a web search fails (e.g. network error), the toggle sometimes reverts from "Search the Web" to "My Foods" automatically. There is no code path that resets `_searchMode` — the only place it changes is the `SegmentedButton.onSelectionChanged`. This needs to be reproduced to identify the root cause (possibly widget recreation during errors).

---

## Acceptance criteria

### #9 (definite)
1. Tapping the `+` quick-log icon on a "My Foods" search result opens the quick-log sheet
2. After logging (or canceling the sheet), the search delegate **closes** and the user returns to the log screen
3. The tap-to-select path (tapping the food name) continues to work as before

### #5 (investigate + fix)
1. The `SegmentedButton` toggle group remains visually centered whether in "My Foods" or "Search the Web" mode
2. No visible shift when toggling between modes

### #8 (investigate + fix)
1. When a web search fails (network error, API error), the toggle stays on "Search the Web"
2. The error message is shown below the toggle
3. The user can retry the search without re-selecting the web mode

---

## Implementation notes

### Fix for #9

The `onQuickLog` callback in `CombinedLogScreen._onSearch()` currently:
```dart
onQuickLog: (item) {
  _showQuickLogSheet(item);
},
```

Change it to:
```dart
onQuickLog: (item) async {
  await _showQuickLogSheet(item);
  // After sheet closes, the search delegate should close itself.
  // But we can't call close() on the delegate from the log screen —
  // instead, make the delegate handle this internally.
},
```

Better approach: have `FoodSearchDelegate` wrap `onQuickLog`:
```dart
// In FoodSearchDelegate:
Future<void> _onQuickLog(FoodSearchItem item) async {
  await onQuickLog?.call(item);
  if (mounted) close(context, null);
}
```

And use this wrapper instead of `onQuickLog` directly in the local search content's `IconButton.onPressed`.

### Investigation for #5

Run the app, open the search delegate, toggle between "My Foods" and "Search the Web". Observe the SegmentedButton's position. If the button shifts, check:
- Parent `Column` alignment
- Whether the SegmentedButton has `width` constraints
- Whether changing content below causes layout shifts

Likely fix: wrap the SegmentedButton in a `SizedBox(width: double.infinity)` or use `Align` with explicit centering.

### Investigation for #8

Add `debugPrint('_searchMode changed to $_searchMode')` in `onSelectionChanged` and `debugPrint('Web search error: ${snapshot.error}')` in the `_WebSearchContent` error path. Reproduce by forcing a network failure (e.g. airplane mode). Check if the search page rebuilds and recreates the state.

---

## Testing

1. Open search, tap quick-log `+` on a food → verify sheet opens
2. Log the food → verify search closes and returns to log screen
3. Cancel the sheet → verify search closes
4. Tap a food name (not `+`) → verify sheet opens, then search closes
5. Toggle between "My Foods" and "Search the Web" → verify toggle stays centered
6. Force a web search failure (airplane mode) → verify toggle stays on "Search the Web"
7. Run `flutter analyze` — zero issues
