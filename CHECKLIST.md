# Implementation Checklist

## Baseline

- [ ] `flutter analyze > analyze.log 2>&1` — zero issues
- [ ] `flutter test > test.log 2>&1` — all tests pass
- [ ] `dart run build_runner build` — drift code generation succeeds (if needed)

> **Note:** This environment has Flutter SDK permission issues (`/root/.pub-cache/` + `/opt/flutter/`). Verify baseline on a properly configured machine before starting.

---

## TICKET-001 — Fix search-toggle not responding when search field has focus

**Files:** `lib/features/logging/widgets/food_search_delegate.dart`

- [ ] **Code changes applied**
  - [ ] `_FoodSearchContentState` has `late String _localSearchMode` initialized in `initState` from `widget.searchMode`
  - [ ] `build()` uses `_localSearchMode` instead of `widget.searchMode`
  - [ ] `onSelectionChanged` calls `setState` + `widget.onSearchModeChanged`
  - [ ] `didUpdateWidget` syncs `_localSearchMode` from `widget.searchMode`

- [ ] **Acceptance criteria verified**
  - [ ] Toggle responds when search field has focus (keyboard open)
  - [ ] Toggle responds when search field does NOT have focus
  - [ ] Toggle survives Enter key (does not auto-reset to "My Foods")
  - [ ] Can toggle back and forth repeatedly
  - [ ] "Create custom food" and barcode scanner still work
  - [ ] Recipe form (`RecipeFormScreen`) unaffected

- [ ] **New test written:** `test/features/logging/search_delegate_test.dart`
  - [ ] Opens search delegate
  - [ ] Taps "Search the Web" — asserts content switches
  - [ ] Taps "My Foods" — asserts content switches back
  - [ ] Types query + Enter — asserts toggle still correct

- [ ] **Regressions checked**
  - [ ] `flutter analyze` — zero issues
  - [ ] `flutter test` — all tests pass (including new test)

---

## TICKET-002 — Tapping list item opens quick-log sheet without closing search

**Files:** `lib/features/logging/widgets/food_search_delegate.dart`

- [ ] **Code changes applied**
  - [ ] `_LocalSearchContent` `ListTile.onTap` calls `onQuickLog!(item)` when available, `onSelectItem(item)` when null
  - [ ] Trailing `Icons.add_circle_outline` button removed

- [ ] **Acceptance criteria verified**
  - [ ] Tapping food list item opens quick-log sheet, search stays open underneath
  - [ ] After save/cancel sheet, search closes automatically
  - [ ] Trailing `+` icon button is gone from "My Foods" results
  - [ ] Recipe form still works (tapping food returns to quantity dialog)
  - [ ] Web search results unaffected
  - [ ] Barcode scanner and "Create custom food" unaffected

- [ ] **Regressions checked**
  - [ ] `flutter analyze` — zero issues
  - [ ] `flutter test` — all tests pass
  - [ ] No changes to recipe form behavior

---

## TICKET-003 — Redesign food entry display

**Files:** `lib/features/logging/combined_log_screen.dart`
**(Optionally)** `lib/features/logging/widgets/macro_bars.dart`

### Macro breakdown bars
- [ ] `_MacroBreakdownBar` widget created
  - [ ] Takes `proteinGrams`, `carbsGrams`, `fatGrams`
  - [ ] Computes caloric contribution (×4, ×4, ×9)
  - [ ] Renders 3 `Expanded` segments with proportional `flex` values
  - [ ] Colors: blue (protein), green (carbs), orange (fat)
  - [ ] Wrapped in `ClipRRect` for rounded corners
  - [ ] Zero-total case returns `SizedBox.shrink()`
  - [ ] Zero-value segments use `clamp(1, 9999)` for visible bar

### Subtitle
- [ ] `ListTile.subtitle` replaced with `_MacroBreakdownBar`
- [ ] Macro text line removed
- [ ] Time removed

### Trailing
- [ ] `_mealTypeBadge` removed from each entry's trailing
- [ ] `Text('${entry.calories.toInt()} cal')` shown in trailing instead
- [ ] `_mealTypeBadge` method deleted (was only used in one place)

### Section headers
- [ ] Added colored left border strip (3px) matching meal type color
- [ ] Added meal type icon next to meal name
- [ ] Entry count badge styled with meal type color

- [ ] **Acceptance criteria verified**
  - [ ] Each entry shows food name + 3 colored proportional bars + "XXX cal"
  - [ ] No macro text, no time, no meal-type badge visible on entries
  - [ ] Section headers show colored border + icon + styled count
  - [ ] Zero-calorie food shows no bar (not a broken layout)
  - [ ] Single-macro food shows a single-color bar
  - [ ] Swipe-to-delete still works
  - [ ] Tap entry still opens `EditEntrySheet`
  - [ ] All meal type colors match existing convention (orange/blue/purple/teal)

- [ ] **Regressions checked**
  - [ ] `flutter analyze` — zero issues
  - [ ] `flutter test` — all tests pass

---

## TICKET-004 — Tighten date-navigation arrows around date text

**Files:** `lib/features/logging/combined_log_screen.dart`

- [ ] **Code changes applied**
  - [ ] Both chevron `IconButton`s moved into `AppBar.title` as `Row(mainAxisSize: MainAxisSize.min)`
  - [ ] `leading` removed (or set to `SizedBox.shrink()`)
  - [ ] Chevrons removed from `actions`
  - [ ] `actions` contains only `menu_book` (recipe log) and `PopupMenuButton` (CSV)
  - [ ] `centerTitle: true` still set

- [ ] **Acceptance criteria verified**
  - [ ] Date text is screen-centered
  - [ ] Chevrons are tight left/right of date text
  - [ ] Recipe-log and CSV menu are on the far right
  - [ ] Date navigation works (chevrons change date correctly)
  - [ ] `DayNavigator.format()` unchanged
  - [ ] "Today"/"Yesterday"/"Tomorrow"/"Jan 15, 2026" all display correctly

- [ ] **Regressions checked**
  - [ ] `flutter analyze` — zero issues
  - [ ] `flutter test` — all tests pass
  - [ ] Existing widget test for "Today" text still passes

---

## Final integration check

- [ ] All 4 tickets implemented
- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — all tests pass (may need to run `dart run build_runner build` first for drift code gen if `database.g.dart` is stale)
- [ ] Manual smoke test: open app → log a food → search for it → toggle search mode → navigate dates → verify entry display
