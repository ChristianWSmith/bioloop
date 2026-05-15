# Discovery Report

Findings from investigating each issue in `issues.txt` against the codebase.

---

## Issue #1 — Onboarding: "Male" should be toggled by default

**File**: `lib/features/onboarding/onboarding_screen.dart`

**Current state**: `_sex` is initialized as `null` (line 23). The `SegmentedButton` for sex at line 372 uses:
```dart
selected: _sex != null ? {_sex!} : {},
emptySelectionAllowed: true,
```
This means neither "Male" nor "Female" is pre-selected on first load.

**Fix**: Initialize `_sex = 'male'` and remove `emptySelectionAllowed: true` from the sex `SegmentedButton`.

**Difficulty**: Trivial. Self-contained change.

---

## Issue #2 — Missing barcode scanning button

**Files**: `lib/features/logging/widgets/barcode_scanner.dart`, `lib/features/logging/widgets/food_search_delegate.dart`, `lib/features/logging/combined_log_screen.dart`

**Current state**: `BarcodeScannerScreen` exists at `barcode_scanner.dart` (full-screen scanner with camera view, MobileScanner, and OpenFoodFacts lookup). Takes an `OpenFoodFactsClient` parameter. No button anywhere in the UI triggers it — it's orphaned code.

**Relevant code paths**:
- `CombinedLogScreen._onSearch()` opens the `FoodSearchDelegate` via `showSearch`
- `FoodSearchDelegate.buildActions()` currently only returns a clear button when `query.isNotEmpty` (line 23-29)
- `FoodSearchDelegate` has access to `searchService` but not directly to `OpenFoodFactsClient`

**Barcode scanner requirements** (from `BarcodeScannerScreen`):
- Scans barcode → looks up via `OpenFoodFactsClient.getByBarcode()`
- On success: pops with `FoodResult`
- On not found: offers "Enter manually" (pops with `'manual'` string) or "Scan again"
- Uses `mobile_scanner` package

**Options for button placement**:
1. **In `buildActions`**: Add a barcode icon button (`Icons.qr_code_scanner`) to the search delegate's AppBar actions, always visible. This is the most standard placement.
2. **In the search content area**: As a prominent button above or near the segmented toggle.
3. **On the log screen AppBar**: As an action alongside the overflow menu.

**Challenge**: The barcode scanner needs an `OpenFoodFactsClient`. Currently `FoodSearchDelegate` only holds a `FoodSearchService`. We can pass the client through the delegate, or access it via a provider inside the scanner.

**Recommendation**: Add the barcode button to `buildActions` in `FoodSearchDelegate`. Pass the API client through the delegate (or have the delegate read it from a provider). When a food is returned from the scanner, pass it to `onQuickLog`.

---

## Issue #3 — Maintenance calc should exclude today

**File**: `lib/core/algorithms/maintenance_calculator.dart`

**Confirmed: today IS included in the regression inputs.**

The evidence:
- `maintenance_provider.dart` line 13: `final now = DateTime.now();` — passes current time
- `maintenance_calculator.dart` line 24: `final today = now ?? DateTime.now();`
- Line 58: `final end = today;` — the loop endpoint is today
- Lines 61-74: The forward-fill loop iterates `for (int d = 0; d <= end.difference(start).inDays; d++)`, which includes today. Any food or weight for today is pulled into the paired data points.

**Impact**: If a user has only logged breakfast and lunch on the current day, the algorithm sees low calorie intake paired with (forward-filled) today's weight, which biases the regression toward estimating a lower maintenance.

**Fix**: The simplest, safest approach: in `maintenance_provider.dart` line 13, change `final now = DateTime.now()` to `final now = DateTime.now().subtract(const Duration(days: 1))`. This shifts the entire 30-day lookback window to end yesterday, cleanly excluding today's partial data.

**Test impact**: The test in `test/core/algorithms/maintenance_calculator_test.dart` uses synthetic data spanning the full last 60 days ending at today. Those tests should still pass because the 60-day span still has 59 days of data within the 30-day window, well above the 14-point minimum.

---

## Issue #4 — Onboarding default goal type should be "Maintain"

**File**: `lib/features/onboarding/onboarding_screen.dart`

**Current state**: Line 32: `String _goalType = 'cut';`

**Fix**: Change to `String _goalType = 'maintain';`

**Secondary effect**: The calorie adjustment controller is initialized at line 33: `final _calorieAdjustmentController = TextEditingController(text: '-500');`. This would need to change to `'0'` to match the "Maintain" preset. Alternatively, the `_onGoalTypeChanged` logic already sets the correct adjustment when the type changes (line 106-115), so we could also call `_onGoalTypeChanged('maintain')` in initState.

**Difficulty**: Trivial.

---

## Issue #5 — Search web toggle off-center

**File**: `lib/features/logging/widgets/food_search_delegate.dart`

**Current state**: The `SegmentedButton<String>` at line 87 is inside a `Column` (line 83) with no explicit `crossAxisAlignment` (defaults to `CrossAxisAlignment.center`). It's wrapped in `Padding(symmetric(horizontal: 16, vertical: 8))`.

**Root cause analysis (requires visual confirmation)**: This is a UI layout issue and needs visual reproduction to diagnose precisely. Likely causes by order of probability:

1. **SegmentedButton width asymmetry**: `SegmentedButton` sizes to its widest segment. "Search the Web" is wider than "My Foods". When the width changes during toggle, the centering within the column produces visible repositioning.
2. **SearchPage layout**: `showSearch` wraps the delegate in a `SearchPage` which may have its own internal padding/structure that affects how the content area aligns.
3. **Transition animation**: During the state change, the old content unmounts and new content mounts, potentially causing a brief layout shift.

**Discovery needed**: Run the app, toggle between modes, and observe the behavior. Check if the issue is the SegmentedButton itself moving or the content below it shifting.

---

## Issue #6 — Day navigator not centered in AppBar

**File**: `lib/features/logging/combined_log_screen.dart` (lines 220-264)

**Current layout** (within the `Scaffold.appBar`):
```dart
AppBar(
  title: DayNavigator(currentDate: ..., onDateChanged: ...),
  actions: [
    PopupMenuButton<String>(...),
  ],
)
```

**Root cause**: In Material's AppBar, when `title` is a widget, its positioning depends on `centerTitle`. By default, the title is centered between the leading widget and the actions. Since there is no leading widget (the back button only appears inside `showSearch`), the available space for the title extends from the left edge to the left edge of the actions. This causes the title to appear shifted left of screen center.

The `DayNavigator` itself internally uses `Row(mainAxisAlignment: MainAxisAlignment.center, ...)` so its own items (chevrons + text) are centered within the DayNavigator. But DayNavigator as a whole is positioned by the AppBar.

**Fix**: Add `centerTitle: true` to the `AppBar` in `CombinedLogScreen` (line 220). This tells the AppBar to center the title widget in the remaining space after accounting for leading and actions, which is what the user expects.

**Verification**: If possible, visually verify after applying the fix. The difference:
- Before: title area center = (screen_width - actions_width) / 2
- After: title area center = screen_width / 2

---

## Issue #7 — Compact macro bars on log screen

**File**: `lib/features/logging/combined_log_screen.dart` (new widget needed)

**Design requirements**:
- Placed above all food entries in the `ListView`
- Shows current day's macro totals as horizontal bars (not rings)
- Calories: full width bar at top
- Protein, Carbs, Fat: three equal-width bars below (1/3 each)
- Gives a quick status glance without going to dashboard

**Data sources already available**:
- `entries` from `ref.watch(dateFoodProvider(_currentDate))` — current code already has this at line 217
- Macro targets from `macroTargetsProvider` — need to add this watch to the `build` method

**Current macro calculations** (already done in `DashboardScreen`, lines 66-69):
```dart
final consumedCals = entries.fold(0.0, (s, e) => s + e.calories);
final consumedProtein = entries.fold(0.0, (s, e) => s + e.proteinGrams);
final consumedFat = entries.fold(0.0, (s, e) => s + e.fatGrams);
final consumedCarbs = entries.fold(0.0, (s, e) => s + e.carbsGrams);
```

**Colors** (from `DashboardScreen` usage):
- Calories: Theme primary color
- Protein: blue
- Carbs: green
- Fat: orange

**Refresh behavior**: The current `QuickFoodLogSheet._log()` (line 95) calls `ref.invalidate(todaysFoodProvider)` after logging, and `CombinedLogScreen.build()` watches `dateFoodProvider(_currentDate)` at line 217. So when a new entry is logged and the bottom sheet closes, the log screen's `entriesAsync` auto-refreshes, which would also refresh the macro bar data.

**Widget design sketch** — a `ConsumerWidget` or stateless widget:
```
┌─────────────────────────────────────┐
│ Calories    1800 / 2500 kcal   ████░░│  ← full width bar
└─────────────────────────────────────┘
┌──────────┬──────────┬──────────┐
│ Protein  │ Carbs    │ Fat      │
│ 120/150g │ 200/300g │ 50/80g   │
│ ████░░   │ █████░░  │ ████░░   │  ← 1/3 width each
└──────────┴──────────┴──────────┘
```

**Implementation approach**: Create a new widget file (e.g., `lib/features/logging/widgets/macro_bars.dart`). Add it to `CombinedLogScreen`'s ListView before the meal groups (around line 301).

---

## Issue #8 — Web search failure toggles back to "My Foods"

**File**: `lib/features/logging/widgets/food_search_delegate.dart`

**Current state**:
- `_searchMode` state is in `_FoodSearchContentState` (line 79), initialized as `'local'`
- The only place `_searchMode` changes is the `SegmentedButton.onSelectionChanged` at line 93
- `_WebSearchContent` (line 186) is a separate `StatefulWidget` — its own error handling at line 254-258 just shows an error `Text`, it doesn't modify `_searchMode`

**The mystery**: There's no code path that programmatically resets `_searchMode` to `'local'`. For the toggle to flip back, `_FoodSearchContentState` would need to be recreated (which would reset to the initial `'local'`).

**Hypotheses** (requires reproduction to confirm):
1. **State recreation**: If the `FoodSearchDelegate` itself is recreated (e.g., the search page gets rebuilt), the entire `_FoodSearchContent` tree would be re-initialized, resetting `_searchMode` to `'local'`. This could happen if the parent widget rebuilds and `showSearch` re-executes.
2. **Error propagation**: If the web search throws an uncaught exception (not handled by `FutureBuilder`'s error builder), it could crash the widget subtree, forcing Flutter to rebuild from scratch.
3. **Key-based recreation**: The `FutureBuilder` at line 244 uses `key: ValueKey(_debouncedQuery)`. When the query changes, this key changes, recreating the `FutureBuilder`. But this shouldn't affect `_searchMode` in the parent state.
4. **User confusion**: The user might see the loading spinner (which is the initial state when query is submitted) followed by the error, and in the transition, the temporarily blank area might look like "it went back to My Foods".

**Discovery needed**: Reproduce the failure scenario and trace what happens. Add `print` or `debugPrint` to `onSelectionChanged` to see if it fires unexpectedly. Or reproduce by making the API call fail (e.g., airplane mode).

---

## Issue #9 — Re-log should return to log screen

**File**: `lib/features/logging/combined_log_screen.dart`

**Current flow**:
1. User taps FAB → `_onSearch()` opens `FoodSearchDelegate` via `showSearch`
2. User taps `+` (quick-log) icon → `onQuickLog(item)` called
3. `_showQuickLogSheet(item)` opens `QuickFoodLogSheet` (modal bottom sheet)
4. User configures, taps "Log to today" → sheet logs, calls `Navigator.pop(true)` → sheet closes
5. **Problem**: User is now looking at the search delegate (still open) — `showSearch` never closed
6. User must manually tap back or cancel to dismiss search

**The quick-log path** vs. the tap-to-select path:
- **Quick-log path** (the `+` icon): calls `onQuickLog(item)` which calls `_showQuickLogSheet(item)` but does **not** close the search delegate. `showSearch` is still showing, awaiting a result.
- **Tap-to-select path** (tapping the food name): calls `onSelectItem(item)` → `close(context, item)` → `showSearch` resolves with the item → `_onSearch()` receives it → calls `_showQuickLogSheet(result)` → sheet opens → user logs → sheet closes → user is back on log screen. This path works correctly.

**Fix**: Make the quick-log flow close the search delegate after the sheet closes. The `onQuickLog` callback needs to:
1. Close the search delegate with `null` result (to prevent the code below from re-triggering)
2. Then open the quick-log sheet

There are two approaches:
- **Approach A**: Have `onQuickLog` be `async`, await the sheet, then call `close(context, null)` on the search delegate.
- **Approach B**: Pass a callback to `FoodSearchDelegate` that gets called after quick-log completes, and have the delegate close itself.

**Approach A is simpler**: Change the `onQuickLog` callback received by `FoodSearchDelegate` to be `Future<void> Function(FoodSearchItem)`, have it close the search first, then show the sheet.

---

## Issue #10 — Remove relog button (redundant)

**File**: `lib/features/logging/combined_log_screen.dart`

**Current state**: In the `ListView` for each entry, there's an `IconButton` with `Icons.replay` at line 370-374:
```dart
if (entry.foodId != null)
  IconButton(
    icon: const Icon(Icons.replay, size: 20),
    tooltip: 'Duplicate entry',
    onPressed: () => _onDuplicate(entry),
  ),
```

**The `_onDuplicate` method** (lines 87-102):
- Looks up the food by `foodId`
- Opens `QuickFoodLogSheet` with pre-filled servings
- Creates a new entry with fresh timestamp

**Rationale for removal**: The user can already re-log by tapping `+` and seeing the food in recent foods (ordered by recency). The relog button is an additional code path for the same action.

**Files affected**:
- Remove the `IconButton` block from the entry widget
- Remove the `_onDuplicate` method
- Remove the import if it was the only usage (check `databaseProvider` usage — it's also used by `_editEntry`)

**Impact**: Reduces visual clutter on each entry row. The `Icons.replay` button currently adds visual noise.

---

## Issue #11 — Log recipe as own button in top bar

**File**: `lib/features/logging/combined_log_screen.dart`

**Current state**: "Log recipe" is a `PopupMenuItem` in the overflow menu (lines 237-244). It calls `_onLogRecipe()` which navigates to `RecipeListScreen` in `pickerMode`.

**Fix**: Add a dedicated `IconButton` in the AppBar's `actions`, alongside (or before) the `PopupMenuButton`. Suggested icon: `Icons.menu_book` or `Icons.book`.

**AppBar actions currently**:
```dart
actions: [
  PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    ...
  ),
],
```

**New AppBar actions**:
```dart
actions: [
  IconButton(
    icon: const Icon(Icons.menu_book),
    tooltip: 'Log recipe',
    onPressed: _onLogRecipe,
  ),
  PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    ...
    // Remove the 'log_recipe' item since it's now a dedicated button
  ),
],
```

**Consideration**: The `PopupMenuButton` currently has 'log_recipe' as its first item. When removing it, the remaining items ('share_food', 'save_food') become the only ones in the menu. Check if the menu still makes visual sense with just two items.

---

## Summary

| Issue | Type | Difficulty | Code change confidence |
|-------|------|------------|----------------------|
| #1 | Bug (default) | Trivial | High — visible in code |
| #2 | Missing feature | Medium | Medium — placement needs decision |
| #3 | Bug (algorithm) | Small | High — clear fix, tests cover it |
| #4 | Bug (default) | Trivial | High — visible in code |
| #5 | UI bug | Unknown | Low — needs visual reproduction |
| #6 | UI bug | Small | High — clear centering issue |
| #7 | New feature | Medium | High — data flow understood |
| #8 | Bug (state) | Unknown | Low — needs reproduction |
| #9 | UX bug | Small | High — flow understood |
| #10 | Removal | Trivial | High — code is self-contained |
| #11 | UI enhancement | Small | High — straightforward addition |
