# Discovery Report — issues.txt

## Overview

There are 5 issues covering the food search screen and the combined log screen. This document traces the relevant code paths, identifies root causes, and proposes targeted fixes for each.

## Issue 1 — Search the Web toggle doesn't respond when search field has focus

### Root cause

`_FoodSearchContentState.build()` reads `widget.searchMode` (a constructor parameter) to set the `SegmentedButton`'s `selected` set. The `onSelectionChanged` callback calls `widget.onSearchModeChanged(v.first)`, which updates the delegate's `_searchMode` field — but **does not call `setState`** on the `_FoodSearchContentState`. Since `widget.searchMode` is still the old value, the `SegmentedButton` rebuilds with `selected: {widget.searchMode}` (still the old mode), making the toggle appear unresponsive.

The fix that introduced the previous Enter-key behavior required `_searchMode` to live on the delegate (not widget state) so it survives `buildResults`/`buildSuggestions` rebuilds. This design is correct, but the stateful widget needs to manage a local copy that it syncs to/from the delegate.

### Code flow

1. `FoodSearchDelegate.buildResults/suggestions` → `_FoodSearchContent(searchMode: _searchMode)` (reads delegate field)
2. `_FoodSearchContentState.build()` → `SegmentedButton(selected: {widget.searchMode})` (reads constructor param)
3. User taps "Search the Web" → `onSelectionChanged` → `widget.onSearchModeChanged('web')` → delegate's `_searchMode = 'web'`
4. Flutter rebuilds because `onSelectionChanged` may trigger tree rebuild... but `widget.searchMode` is still `'local'` → `selected` stays `{'local'}` → toggle stays stuck on "My Foods"

The barcode scanner "fix" works because it pushes a full-screen route. When the user pops back (with `null` result), the `_FoodSearchContent` is freshly created in `buildResults`/`buildSuggestions`. This new widget picks up `_searchMode` from the delegate field, which *was* updated earlier but never took effect visually.

### Files affected

- `lib/features/logging/widgets/food_search_delegate.dart` (lines 124–161)

### Fix: promote local state in `_FoodSearchContentState`

- Add `late String _localSearchMode` initialized in `initState` from `widget.searchMode`
- `onSelectionChanged`: `setState(() => _localSearchMode = v.first)` + `widget.onSearchModeChanged(v.first)`
- `build()`: use `_localSearchMode` everywhere instead of `widget.searchMode`
- Override `didUpdateWidget`: if `oldWidget.searchMode != newWidget.searchMode`, sync `_localSearchMode` (handles Enter-key rebuilds from delegate)

This preserves the Enter-key survival requirement (delegate still stores the authoritative `_searchMode`) while making the toggle interactive (local state drives the build).

---

## Issue 2 — Tapping list entry should quick-log without closing search

### Current behavior (two paths)

**Path A — tapping list item** (`_LocalSearchContent` line 217):
```dart
onTap: () => onSelectItem(item)
```
This calls `close(context, item)` in `FoodSearchDelegate.buildResults/suggestions`, which closes the search and returns the item via `showSearch`. Then `CombinedLogScreen._onSearch()` (line 57–58) opens the quick-log sheet:
```dart
if (result != null) {
  _showQuickLogSheet(result);
}
```

**Path B — tapping quick-log button** (`_LocalSearchContent` line 218–223):
```dart
trailing: onQuickLog != null
    ? IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => onQuickLog!(item),
      )
    : null,
```
The wrapper in `buildResults`/`buildSuggestions`:
```dart
onQuickLog: onQuickLog != null
    ? (item) async {
        final nav = Navigator.of(context);
        await onQuickLog!(item);        // opens sheet (search stays underneath)
        nav.pop<FoodSearchItem?>(null); // closes delegate after sheet returns
      }
    : null,
```

Path B is what the user wants for Path A too: the sheet opens over the search, and only returns to the log tab when save/cancel dismisses the sheet.

### Why the recipe form is NOT affected

`RecipeFormScreen._addIngredient()` does NOT pass `onQuickLog` to `FoodSearchDelegate`. In `_LocalSearchContent`, the trailing button is conditionally hidden when `onQuickLog == null` (line 218: `trailing: onQuickLog != null ? ... : null`). The recipe form relies on `onSelectItem` to return the selected food — this should remain unchanged.

### Files affected

- `lib/features/logging/widgets/food_search_delegate.dart` (lines 211–225 in `_LocalSearchContent`)

### Fix

When `onQuickLog` is available:
- Change `onTap` on the food item `ListTile` from `onSelectItem(item)` to `onQuickLog!(item)` (same as the button)
- Remove the trailing `IconButton` (lines 218–224)
- Keep `onSelectItem` as the fallback when `onQuickLog` is null (recipe form use case)

---

## Issue 3 — Per-food macro breakdown bars

### Current display

Each entry `ListTile` in `combined_log_screen.dart` line 378–384 shows:
```dart
subtitle: Text(
  '${entry.calories.toInt()} cal  •  '
  'P${entry.proteinGrams.toStringAsFixed(0)}g  '
  'C${entry.carbsGrams.toStringAsFixed(0)}g  '
  'F${entry.fatGrams.toStringAsFixed(0)}g'
  '${_timeFromLoggedAt(entry.loggedAt) != null ? "  •  ${_timeFromLoggedAt(entry.loggedAt)}" : ""}',
),
```

### Desired display

Replace the subtitle with 3 proportional bars in a row:
- Protein (blue): width proportional to `proteinGrams × 4` cal
- Carbs (green): width proportional to `carbsGrams × 4` cal
- Fat (orange): width proportional to `fatGrams × 9` cal
- Total width fills the available space

Use `Expanded` with `flex: <calorie_contribution_as_int>` for exact proportional widths.

### Calorie color scheme (from existing code)

| Macro | Color | Cal/g |
|-------|-------|-------|
| Protein | `Colors.blue` | 4 |
| Carbs | `Colors.green` | 4 |
| Fat | `Colors.orange` | 9 |

### Files affected

- `lib/features/logging/combined_log_screen.dart` (line 378–384, the ListTile subtitle)
- Possibly `lib/features/logging/widgets/macro_bars.dart` if extracting the mini bar as a reusable widget

### Fix: new `_MacroBreakdownBar` widget

Create a widget that takes `proteinGrams`, `carbsGrams`, `fatGrams` and renders a `Row` of 3 `Expanded` children with proportional `flex` values (int-based), wrapped in `ClipRRect` for rounded corners. Replace the subtitle `Text` with this widget.

---

## Issue 4 — Date nav arrows tight to date text

### Current structure

```dart
// combined_log_screen.dart lines 210–258
AppBar(
  centerTitle: true,
  title: Text(_formatDateText()),
  leading: IconButton(icon: chevron_left, onPressed: ...),     // far left
  actions: [
    IconButton(icon: chevron_right, onPressed: ...),           // left of other actions
    IconButton(icon: menu_book, onPressed: ...),               // recipe log
    PopupMenuButton(more_vert, ...),                            // CSV menu
  ],
)
```

The chevron buttons are at the AppBar edges because `leading` is pinned to the far left and `actions[0]` is right-aligned. `centerTitle: true` centers the title between these, leaving a gap between the title and the chevrons.

### Desired structure

The date text should stay screen-centered. The chevron buttons should be directly adjacent to the text (tight left/right). Other action icons (recipe log, CSV menu) stay on the far right.

### Files affected

- `lib/features/logging/combined_log_screen.dart` (lines 210–258, the AppBar)

### Fix

Move both chevrons into the `title` as a tightly-packed `Row`:
```dart
title: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(icon: chevron_left, onPressed: ...),
    Text(_formatDateText()),
    IconButton(icon: chevron_right, onPressed: ...),
  ],
),
centerTitle: true,   // still needed to center the Row
```
Remove `leading` entirely (or set to `const SizedBox()`). Remove the chevrons from `actions` — only keep `menu_book` and `PopupMenuButton`.

---

## Issue 5 — Remove meal badges, improve section markers, show calories on right

### Current section header (lines 321–341)

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
  child: Row(
    children: [
      Text(mealType, style: labelMedium, onSurfaceVariant, w600),
      SizedBox(width: 8),
      Text('${count}', style: labelSmall, onSurfaceVariant),
    ],
  ),
),
```
Plain text with muted color (`onSurfaceVariant`), small count badge. No visual distinction.

### Current entry trailing (lines 385–390)

```dart
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _mealTypeBadge(entry.mealType),   // colored rounded chip
  ],
),
```
The `_mealTypeBadge` (lines 160–182) renders a small rounded `Container` with tinted background and meal type name.

### Current meal type colors (defined in `_mealTypeBadge`)

| Meal | Color |
|------|-------|
| breakfast | `Colors.orange` |
| lunch | `Colors.blue` |
| dinner | `Colors.purple` |
| snack | `Colors.teal` |

These colors should be reused for the section header indicators.

### Files affected

- `lib/features/logging/combined_log_screen.dart` (lines 160–182, 320–394)

### Fix

1. **Section headers** — Add a colored left border strip matching the meal type color (use the same color map from `_mealTypeBadge`). This makes each meal section visually distinct:
   ```dart
   Container(
     decoration: BoxDecoration(
       border: Border(left: BorderSide(color: mealColors[mealType], width: 3)),
     ),
     padding: EdgeInsets.only(left: 8),
     child: Text(mealType, ...),
   )
   ```
   Keep or enhance the meal type icon from `MealTypeSelector` (`Icons.free_breakfast`, etc.) next to the text.

2. **Remove badges** — Delete `_mealTypeBadge` usage from each entry's trailing (lines 385–390).

3. **Show calories** — Replace with a `Text` widget showing the entry's calorie count, styled to be visible but compact:
   ```dart
   trailing: Text(
     '${entry.calories.toInt()} cal',
     style: Theme.of(context).textTheme.bodyMedium?.copyWith(
       fontWeight: FontWeight.w600,
     ),
   )
   ```

---

## Test Coverage & Impact

### Existing tests (no widget tests for affected screens)

| Test file | Tests | Affected? |
|-----------|-------|-----------|
| `test/providers/food_search_provider_test.dart` | `FoodSearchService.searchLocal/searchWeb/auto-save` | No (service-layer tests, no UI) |
| `test/widget_test.dart` | App shell, onboarding | No |
| `test/features/logging/manual_food_form_test.dart` | Manual food form | No |
| `test/features/logging/barcode_scanner_test.dart` | Barcode scanner | No |
| All other test files | Other features | No |

**Gap:** There are no widget tests for `FoodSearchDelegate`, `CombinedLogScreen`, or any of the log-screen entry rendering. For Issue 1 specifically (toggle fix), a new widget test is needed.

### New test needed for Issue 1

A `testWidgets` test should:
1. Create an in-memory DB + mock API client
2. Open the search delegate via `showSearch`
3. Tap "Search the Web"
4. Assert the content area switches from `_LocalSearchContent` to `_WebSearchContent`
5. Tap "My Foods"
6. Assert it switches back
7. (If possible) Type a query and press Enter, then verify toggle still works

---

## Summary of files to modify

| File | Issues | Changes |
|------|--------|---------|
| `lib/features/logging/widgets/food_search_delegate.dart` | 1, 2 | Local state for toggle + list-item tap behavior + remove trailing button |
| `lib/features/logging/combined_log_screen.dart` | 3, 4, 5 | Macro bars in subtitle, date nav restructure, section headers, trailing calories |
| `lib/features/logging/widgets/macro_bars.dart` | 3 | (Optional) Add `_MacroBreakdownBar` widget here |
| `test/providers/food_search_provider_test.dart` or new test file | 1 | Widget test for toggle interaction |

No other callers are affected — `RecipeFormScreen` does not pass `onQuickLog`, so its behavior is unchanged for Issues 1–2.
