# Discovery Report

## Issue 1 — Edit entry quantity hint shows "100 g" instead of just "g"

### Confirmed root cause

`QuickFoodLogSheet._buildLabel()` (`lib/features/logging/widgets/quick_food_log_sheet.dart:44-49`) constructs `'$qtyStr $unit'`, e.g. `"100 g"` or `"3 servings"`. This string is saved as `servingLabel` on the `FoodEntry` at line 87:

```dart
servingLabel: _buildLabel(_servings, _unit),
```

When the entry is later edited in `EditEntrySheet` (`lib/features/history/widgets/edit_entry_sheet.dart:181`), `servingLabel` is displayed as the `suffixText`:

```dart
suffixText: widget.entry.servingLabel,
```

So the text field suffix reads `"100 g"` (quantity + unit) instead of just `"g"` (unit only).

### Fix required

`quick_food_log_sheet.dart:87` — change `servingLabel: _buildLabel(_servings, _unit)` to `servingLabel: _unit`. The `_buildLabel` method (lines 44-49) can be removed or simplified since its only consumer is this line.

### Files affected
- `lib/features/logging/widgets/quick_food_log_sheet.dart:44-49,87`

---

## Issue 2 — Date switcher "Today" text is left of screen center

### Confirmed root cause

`DayNavigator` (`lib/features/logging/widgets/day_navigator.dart:28-44`) is a `Row` containing `[IconButton(left), Text("Today"), IconButton(right)]` with `MainAxisAlignment.center`. This Row is passed as the `title` of an `AppBar` with `centerTitle: true` (`combined_log_screen.dart:209`).

The `centerTitle: true` centers the **entire Row** in the space between `leading` and the right edge of the app bar. The right-side actions (`menu_book` icon + popup menu) eat into the right side. Within the Row, the text is centered between the two IconButtons, but the Row itself is centered in the available space — so the text ends up visually left of screen center.

### Fix required

Restructure the app bar so the date text can be truly screen-centered. Approaches:

1. **Move chevrons to AppBar `leading`/`actions`**: Remove the IconButtons from `DayNavigator`, pass only the text as the AppBar `title`, and put the left chevron as a custom `leading` widget and the right chevron as the first action. This lets `centerTitle` work correctly with just the text.

2. **Use a `Stack`**: Keep everything in `DayNavigator` but wrap in a `Stack` with the text `Center`-ed and the IconButtons positioned at edges. The left is fine, the right needs to account for action button widths by using a `LayoutBuilder` or hardcoded padding.

3. **Remove `centerTitle` and manually center**: Remove `centerTitle`, use `title: Text(...)` only, and put the chevrons in the `leading`/`actions` positions.

### Files affected
- `lib/features/logging/widgets/day_navigator.dart`
- `lib/features/logging/combined_log_screen.dart:208-213`

---

## Issue 3 — Enter key on web search toggles back to "My Foods"

### Confirmed root cause

`_FoodSearchContentState` (`lib/features/logging/widgets/food_search_delegate.dart:115-153`) initializes `_searchMode = 'local'` on line 116. `SearchDelegate` calls:
- `buildSuggestions` on every keystroke
- `buildResults` when Enter is pressed

Both methods at lines 66 and 81 create a **new** `_FoodSearchContent` widget each time, which means `_FoodSearchContentState` is re-initialized with `_searchMode = 'local'`. If the user had toggled to "Search the Web" and then presses Enter, the fresh widget resets to "My Foods".

Additionally, the web search (`_WebSearchContentState`, line 265-272) relies on a 400ms debounce timer triggered by `didUpdateWidget`. There is no `onSubmitted` override or `TextInputAction.search` handler to fire an immediate search on Enter. The Enter key does nothing for the web search itself — it just triggers `buildResults`, which resets the segmented control to 'local'.

### Fix required

Preserve the `_searchMode` across `buildResults`/`buildSuggestions` rebuilds. Options:

1. **Store `_searchMode` in the SearchDelegate**: Move the `_searchMode` state into `FoodSearchDelegate` itself (or a ValueNotifier on it). Pass the current mode to `_FoodSearchContent` so it's preserved across rebuilds.

2. **Use query prefix convention**: Encode the search mode in the query string (e.g., `web:chicken`).

3. **Override `onQueryChanged`**: Intercept query changes in the delegate and debounce there, so Enter doesn't trigger a `buildResults` that destroys the widget state.

### Files affected
- `lib/features/logging/widgets/food_search_delegate.dart`

---

## Issue 4 — Recipe ingredient quantity defaults to 1 instead of serving quantity

### Confirmed root cause

Two paths for adding ingredients:

**Path A — via search dialog** (`lib/features/recipes/recipe_form_screen.dart:98-106`):
```dart
final quantityStr = await showDialog<String>(
  context: context,
  builder: (ctx) => _QuantityDialog(
    foodName: food.name,
    unit: food.servingUnit,
    // initialValue is NOT passed — defaults to null
  ),
);
```
`_QuantityDialog.initState` (line 440):
```dart
_controller = TextEditingController(text: widget.initialValue ?? '1');
```

**Path B — direct from custom food** (`lib/features/recipes/recipe_form_screen.dart:136-148`):
```dart
quantity: 1,  // hardcoded
```

Neither path uses `food.servingQuantity` as the default. For per-100g foods (`servingQuantity=100`), defaulting to `1` means 1g is used instead of a full serving (100g).

### Fix required

- **Path A** (line 101-103): Pass `initialValue: food.servingQuantity.toString()` to `_QuantityDialog`
- **Path B** (line 143): Change `quantity: 1` to `quantity: food.servingQuantity`

### Files affected
- `lib/features/recipes/recipe_form_screen.dart:98-106,143`

---

## Issue 5 — Onboarding back-out leaves black screen instead of closing app

### Confirmed root cause

`OnboardingScreen` (`lib/features/onboarding/onboarding_screen.dart:293-295`):
```dart
if (shouldPop == true && mounted) {
  setState(() => _canPop = true);
  Navigator.of(context).pop();  // pops the route, nothing beneath it
}
```

`OnboardingScreen` is the `home` of `MaterialApp` (returned from `App._buildHome()`, `app.dart:79`). There is no route beneath it in the navigation stack. Popping removes the only route, leaving a blank/black screen (the default Material background).

The `PopScope` (line 355-360) originally blocks the back button. After confirmation, `_canPop` is set to `true` and `Navigator.pop()` is called — but with no route beneath, the screen goes black.

### Fix required

Replace `Navigator.of(context).pop()` with `SystemNavigator.pop()` from `package:flutter/services.dart` to exit the app entirely:

```dart
import 'package:flutter/services.dart';

// in _showDiscardDialog, after confirmation:
if (shouldPop == true && mounted) {
  SystemNavigator.pop();
}
```

### Files affected
- `lib/features/onboarding/onboarding_screen.dart:1,293-295`

---

## Issue 6 — Protein/fat goal updates don't propagate to macro targets

### Confirmed root cause

The propagation chain is broken at the provider link.

`macroTargetsProvider` (`lib/providers/macro_targets_provider.dart:83-95`):
```dart
final macroTargetsProvider = FutureProvider<MacroTargets>((ref) async {
  final goals = await ref.watch(goalsProvider).getGoals();
  final entries = await ref.watch(bodyweightProvider.future);
  final maintenanceResult = await ref.watch(maintenanceProvider.future);
  ...
```

It watches `goalsProvider` (a plain `Provider<GoalsService>`) and calls `.getGoals()` to read from the DB. A plain `Provider` does not react to DB mutations — it only re-runs when its own dependencies change.

`GoalsScreen._save()` (`lib/features/goals/goals_screen.dart:277`) invalidates only `userGoalsProvider`:
```dart
ref.invalidate(userGoalsProvider);
```

`userGoalsProvider` is a `FutureProvider<UserGoal?>` (`lib/providers/goals_provider.dart:11-14`) that reads from the DB. But `macroTargetsProvider` does NOT watch `userGoalsProvider` — it watches `goalsProvider`. So the invalidation of `userGoalsProvider` has no effect on `macroTargetsProvider`.

`maintenanceProvider` (`lib/providers/maintenance_provider.dart:8-24`) watches `dataTriggerProvider` and `resetTriggerProvider`, but `GoalsScreen._save()` doesn't touch either of these.

### Fix required

**Option A (minimal, recommended)**: Change `macroTargetsProvider` to watch `userGoalsProvider` (which IS reactive to invalidation) instead of calling `goalsProvider.getGoals()`:

```dart
// Change line 84 from:
final goals = await ref.watch(goalsProvider).getGoals();
// To:
final goals = await ref.watch(userGoalsProvider);
```

This way, when `GoalsScreen._save()` invalidates `userGoalsProvider`, `macroTargetsProvider` will re-run.

**Option B (belt-and-suspenders)**: Also increment `dataTriggerProvider` in `GoalsScreen._save()` alongside the `userGoalsProvider` invalidation, which will additionally refresh `maintenanceProvider`.

### Files affected
- `lib/providers/macro_targets_provider.dart:84`
- Possibly `lib/features/goals/goals_screen.dart:277` (for Option B)

---

## Issue 7 — "Create custom food" button doesn't open the form

### Confirmed root cause

`_LocalSearchContent` (`lib/features/logging/widgets/food_search_delegate.dart:184-189`):
```dart
ListTile(
  leading: const Icon(Icons.add_circle_outline),
  title: const Text('Create custom food'),
  onTap: () {
    onCreateCustomFood();          // sets flag, but does NOT close delegate
  },
),
```

The barcode scanner path (lines 43-45) demonstrates the correct pattern — set the flag AND close the delegate:
```dart
} else if (result == 'manual') {
  onCreateCustomFood();
  navigator.pop<FoodSearchItem?>(null);  // ✅ closes delegate
}
```

In `CombinedLogScreen` (`lib/features/logging/combined_log_screen.dart:55-60`), the flag is checked after the delegate closes:
```dart
} else if (_pendingCreateCustom) {
  _pendingCreateCustom = false;
  _openCreateCustom();  // opens ManualFoodForm
}
```

But since the ListTile's `onTap` never closes the delegate, the user sees no response and must manually press back. Only then does the form appear.

### Fix required

Add a `Navigator.of(context).pop<FoodSearchItem?>(null);` after `onCreateCustomFood()` in the ListTile's `onTap` at line 189:

```dart
onTap: () {
  onCreateCustomFood();
  Navigator.of(context).pop<FoodSearchItem?>(null);
},
```

This mirrors the exact pattern used in the barcode scanner handler.

### Files affected
- `lib/features/logging/widgets/food_search_delegate.dart:188-189`

---

## Summary of fixes

| # | Priority | Effort | Fix description | File(s) |
|---|----------|--------|----------------|---------|
| 7 | High | 1 line | Add `navigator.pop()` after `onCreateCustomFood()` in search ListTile | `food_search_delegate.dart:189` |
| 4 | High | 2 lines | Default recipe ingredient qty to `food.servingQuantity` | `recipe_form_screen.dart:103,143` |
| 1 | Medium | 2 lines | Save just `_unit` as `servingLabel` instead of `_buildLabel()` output | `quick_food_log_sheet.dart:87` |
| 6 | High | 1 line | Watch `userGoalsProvider` instead of `goalsProvider.getGoals()` | `macro_targets_provider.dart:84` |
| 5 | Medium | 2 lines | Use `SystemNavigator.pop()` to close app on onboarding discard | `onboarding_screen.dart:1,295` |
| 3 | Medium | ~10 lines | Persist `_searchMode` across `buildResults`/`buildSuggestions` rebuilds | `food_search_delegate.dart` |
| 2 | Low | ~20 lines | Restructure AppBar layout so date text is truly screen-centered | `day_navigator.dart`, `combined_log_screen.dart` |
