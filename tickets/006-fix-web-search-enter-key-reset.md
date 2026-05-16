# Ticket 6: Fix Enter key on web search resetting to "My Foods"

**Issue:** #3  
**Priority:** Medium  
**Effort:** ~10 lines  
**File:** `lib/features/logging/widgets/food_search_delegate.dart`

## Context

When the user toggles to "Search the Web" and types a query, pressing Enter on their keyboard causes the segmented control to reset back to "My Foods". The web search never completes.

### Root cause

`_FoodSearchContentState` initializes `_searchMode = 'local'` at construction (line 116). `SearchDelegate` calls:
- `buildSuggestions` on every keystroke — creates a fresh `_FoodSearchContent` widget
- `buildResults` when the user presses Enter — creates another fresh `_FoodSearchContent` widget

Each fresh widget gets a new `_FoodSearchContentState` with `_searchMode = 'local'`. So pressing Enter after toggling to web search destroys the current widget tree, the state is lost, and the new widget defaults to "My Foods".

Additionally, the web search (`_WebSearchContentState`) relies on a 400ms debounce timer in `didUpdateWidget`. The Enter key does nothing useful for web search — it neither fires the search immediately nor dismisses the keyboard.

### Fix

Lift the `_searchMode` state from `_FoodSearchContentState` up to `FoodSearchDelegate`, which persists across `buildResults`/`buildSuggestions` calls.

## Acceptance criteria

- [ ] Open search → switch to "Search the Web" → type a query → press Enter → stays on "Search the Web"
- [ ] The web search results still debounce properly (400ms after last keystroke)
- [ ] Switching between local and web modes works smoothly without unexpected toggles
- [ ] Dismiss search (back button) and re-open → defaults to "My Foods"
- [ ] Typing in "My Foods" mode → pressing Enter → stays on "My Foods"
- [ ] No regression: local search still filters results on keystroke
- [ ] No regression: web search still shows results after debounce

## Testing

### Manual testing
1. Open food search log → segmented control shows "My Foods"
2. Tap "Search the Web" → type "chicken" → press Enter on keyboard
3. Verify: still on "Search the Web" tab, keyboard dismissed
4. Wait for debounce (400ms) → results appear
5. Tap "My Foods" → type "egg" → press Enter → stays on "My Foods"
6. Close search → re-open → defaults to "My Foods"

### Regression checks
- The `_searchMode` is only used for the segmented button toggle. Lifting it to the delegate does not affect search results filtering.
- `_WebSearchContent` debounce logic is untouched — still fires 400ms after last query change.
- `buildResults` and `buildSuggestions` still return the same content structure — no visual change.

## Implementation

```dart
// In FoodSearchDelegate class, add a field:
class FoodSearchDelegate extends SearchDelegate<FoodSearchItem?> {
  // ... existing fields ...
  String _searchMode = 'local';  // lifted from _FoodSearchContentState

  // Pass _searchMode to _FoodSearchContent:
  @override
  Widget buildResults(BuildContext context) => _FoodSearchContent(
        searchMode: _searchMode,
        onSearchModeChanged: (v) => _searchMode = v,
        // ... other params unchanged ...
      );

  @override
  Widget buildSuggestions(BuildContext context) => _FoodSearchContent(
        searchMode: _searchMode,
        onSearchModeChanged: (v) => _searchMode = v,
        // ... other params unchanged ...
      );
}

// In _FoodSearchContent, add constructor params:
class _FoodSearchContent extends StatefulWidget {
  final String searchMode;
  final ValueChanged<String> onSearchModeChanged;
  // ... existing params ...
}

// In _FoodSearchContentState, use widget.searchMode instead of local state:
// Remove: String _searchMode = 'local';
// In build(), change:
//   selected: {_searchMode},
// To:
//   selected: {widget.searchMode},
// Change onSelectionChanged from:
//   (v) => setState(() => _searchMode = v.first),
// To:
//   (v) => widget.onSearchModeChanged(v.first),
```
