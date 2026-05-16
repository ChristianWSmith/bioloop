# TICKET-001: Fix search-toggle not responding when search field has focus

**Priority:** High (UX bug — toggle appears unresponsive)
**File:** `lib/features/logging/widgets/food_search_delegate.dart`
**Estimate:** ~1h

---

## Context

The "My Foods" / "Search the Web" segmented toggle in the food search screen does not respond to taps when the search field has focus. The user must first tap the barcode scanner button and then back out (which loses focus) to make the toggle work. This bug was likely introduced when fixing a previous issue where pressing Enter would auto-reset the toggle to "My Foods".

### Root cause (from DISCOVERY.md)

`_FoodSearchContentState.build()` reads `widget.searchMode` (a constructor parameter) to set `SegmentedButton.selected`. The `onSelectionChanged` callback updates the delegate's `_searchMode` via `widget.onSearchModeChanged(v.first)`, but **never calls `setState`** on the widget state. So `widget.searchMode` (still the old value) continues to drive the build, and the `SegmentedButton` re-selects the old segment on every rebuild.

The previous fix required `_searchMode` to live on the delegate (not widget state) so it survives `buildResults`/`buildSuggestions` rebuilds when Enter is pressed. This design intent is correct but the implementation is incomplete — the stateful widget needs a local copy that drives the UI and syncs to/from the delegate.

### Key constraint

The Enter key triggers `buildResults`, which creates a fresh `_FoodSearchContent` widget. This rebuild must pick up the delegate's current `_searchMode`, not an old value. The fix must preserve this behavior.

---

## Acceptance criteria

1. **Toggle responds when search field has focus**: tapping "Search the Web" immediately switches the content below from local food list to web search results (or empty state), and the toggle visually updates to "Search the Web".
2. **Toggle responds when search field does NOT have focus**: same behavior as above.
3. **Toggle survives Enter key**: after typing a query and pressing Enter, the toggle retains its current selection (does not auto-reset to "My Foods").
4. **Toggling back and forth**: user can switch between "My Foods" and "Search the Web" repeatedly without issues.
5. **No regression**: "Create custom food" and barcode scanner still work. `RecipeFormScreen` (which does not pass `onQuickLog`) is unaffected.

---

## Implementation plan

1. In `_FoodSearchContentState`, add a `late String _localSearchMode` field.
2. In `initState`, initialize from `widget.searchMode`.
3. Change `build()` to reference `_localSearchMode` instead of `widget.searchMode`.
4. Change the `SegmentedButton.onSelectionChanged` to:
   ```dart
   setState(() => _localSearchMode = v.first);
   widget.onSearchModeChanged(v.first);
   ```
5. Override `didUpdateWidget` to sync `_localSearchMode` when the delegate rebuilds:
   ```dart
   @override
   void didUpdateWidget(_FoodSearchContent oldWidget) {
     super.didUpdateWidget(oldWidget);
     if (widget.searchMode != oldWidget.searchMode) {
       _localSearchMode = widget.searchMode;
     }
   }
   ```

---

## Testing

### New widget test: `test/features/logging/search_delegate_test.dart`

A `testWidgets` test that:
1. Creates an in-memory `AppDatabase` + mock `OpenFoodFactsClient` (using `MockClient`)
2. Seeds 2–3 foods in the DB
3. Builds a `MaterialApp` with the search delegate opened via `showSearch`
4. Asserts the toggle shows "My Foods" as selected initially
5. Finds the `SegmentedButton<String>`, taps "Search the Web"
6. Asserts the content switches from `_LocalSearchContent` to `_WebSearchContent` (by checking for "Enter a search term" text)
7. Taps back to "My Foods"
8. Asserts content switches back (by checking for "Create custom food" text)
9. Types a query into the search field, presses Enter
10. Asserts the toggle is still on "My Foods"
11. Toggles to "Search the Web" again and asserts it works

### Regression verification

- Run `flutter test > test.log 2>&1` — all existing tests must pass
- Run `flutter analyze > analyze.log 2>&1` — zero issues
