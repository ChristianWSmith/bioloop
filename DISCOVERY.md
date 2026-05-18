# Discovery Report

Generated: 2026-05-18

---

## D1: Maintenance days count includes today when it shouldn't

### Problem
The maintenance card shows "2/10 days logged" when the user has logged food for yesterday and today. The regression algorithm excludes today (by design, since today's data is partial), but the progress bar counts today. This misleads users into thinking they're closer to getting a maintenance estimate than they actually are.

### Root Cause
Two different date windows are used:

| Component | Window end | Includes today? |
|---|---|---|
| `_countDataDaysProvider` (progress bar) | `DateTime.now()` | Yes |
| `maintenanceProvider` (regression) | `DateTime.now() - 1 day` | No |

**`maintenance_card.dart:12-28`** — `_countDataDaysProvider`:
```dart
final now = DateTime.now();                          // ← includes today
final cutoff = now.subtract(const Duration(days: 30));
```

**`maintenance_provider.dart:12`** — regression:
```dart
final now = DateTime.now().subtract(const Duration(days: 1));  // ← excludes today
```

Additionally, the progress bar counts **distinct calendar days with food entries**, but the regression requires **paired (calories + weight-slope) data points** — these are fundamentally different metrics. A "paired data point" is a 7-day rolling window with ≥3 weight points and ≥3 calorie days. The threshold is 10 such windows (`maintenance_calculator.dart:175`).

### Files to change
- `lib/features/dashboard/widgets/maintenance_card.dart:12-28, 84-141`

### Proposed fix
1. **Align the window**: Change `DateTime.now()` → `DateTime.now().subtract(const Duration(days: 1))` in `_countDataDaysProvider`.
2. **Match the metric**: Instead of counting distinct food-logging days, use `maintenanceProvider`'s `result.dataPoints` field (already computed by the regression). The progress bar becomes `min(dataPoints, 10) / 10`. This eliminates the separate provider entirely and shows the exact same number the regression uses.

### Risk
Medium. `MaintenanceResult` already has `dataPoints` — we just need to surface it in the insufficient-data path. Edge case: when `maintenanceProvider` is loading, the progress bar should show a loading indicator (already handled by the existing `when()` pattern).

---

## D2: Calories sparkline excludes today's data

### Problem
The calories consumed sparkline on the dashboard does not show today's calorie data, even when food has been logged today.

### Root Cause
Lexicographic string comparison bug in `getEntriesForDateRange()`.

**`database.dart:165-174`**:
```dart
final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
// ...isBetweenValues(startStr, endStr)
```

The `loggedAt` column stores timestamps like `"2026-05-18 14:30:00"`. The `endStr` is `"2026-05-18"`. The `isBetweenValues` check is `>= startStr AND <= endStr`. Since `"2026-05-18 14:30:00" > "2026-05-18"` lexicographically, all of today's entries are excluded.

**Data flow**:
1. `dashboard_screen.dart:63-67` — `DashboardRange.compute()` sets `range.end` to today (midnight)
2. `dashboard_screen.dart:69-74` — `historicalCaloriesProvider(start: range.start, end: range.end)` is called
3. `food_log_provider.dart:48-61` — calls `getEntriesForDateRange(params.start, params.end)`
4. `database.dart:165-174` — formats `end` as date-only string, uses `isBetweenValues`

### Files to change
- `lib/core/database/database.dart:165-174`

### Proposed fix
Change the end boundary to `end.add(const Duration(days: 1))` so the comparison becomes `<= "2026-05-19"`, which captures all timestamps on the end date:
```dart
final endStr = '${end.add(const Duration(days: 1)).year}-...';
```

### Risk
Low. Single-line change. Need to verify no other callers of `getEntriesForDateRange()` rely on exclusive-end behavior. Current callers:
- `historicalCaloriesProvider` (food_log_provider.dart:52) — wants inclusive
- `historicalCalories30DaysProvider` (food_log_provider.dart:66) — wants inclusive

---

## F1: Whole number quantity formatting shows ".0" suffix

### Problem
When logging or editing food/recipe entries, whole numbers display with a trailing `.0` (e.g., "100.0" instead of "100"). This adds unnecessary friction — users must delete the `.0` before submitting.

### Root Cause
The app already has a consistent "smart formatting" pattern used in `ServingSizePicker` and `RecipeIngredientRow`:
```dart
value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1)
```

But four locations use `.toStringAsFixed(1)` or `.toString()` instead:

| File | Line | Context | Current | Displays "100.0" as |
|---|---|---|---|---|
| `edit_entry_sheet.dart` | 39 | Servings controller init | `e.servings.toStringAsFixed(1)` | `"100.0"` |
| `recipe_form_screen.dart` | 89 | Add ingredient default | `food.servingQuantity.toString()` | `"100.0"` |
| `recipe_form_screen.dart` | 130 | Edit ingredient default | `item.ingredient.quantity.toStringAsFixed(1)` | `"100.0"` |
| `manual_food_form.dart` | 40 | Existing food quantity | `food.servingQuantity.toString()` | `"100.0"` |

### Already correct (reference implementations)
| File | Line | Pattern |
|---|---|---|
| `serving_size_picker.dart` | 35-39 | `roundToDouble() ? toInt() : toStringAsFixed(1)` |
| `serving_size_picker.dart` | 45-49 | Same in `didUpdateWidget` |
| `recipe_ingredient_row.dart` | 48-50 | Same for display |
| `manual_food_form.dart` | 68-72 | Same in `_buildLabel()` |

### Files to change
- `lib/features/history/widgets/edit_entry_sheet.dart:38-39`
- `lib/features/recipes/recipe_form_screen.dart:89`
- `lib/features/recipes/recipe_form_screen.dart:130`
- `lib/features/logging/widgets/manual_food_form.dart:40`

### Proposed fix
Replace each occurrence with the smart formatting pattern. Consider extracting a helper function to avoid repetition:
```dart
String formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
```

### Risk
Low. Display-only change. Internal data model remains `double`. No behavior change for non-whole numbers.

---

## BW1: Move "+ Log weight" button to FAB

### Problem
The bodyweight screen uses an inline `FilledButton.icon` in a custom header row, inconsistent with the `FloatingActionButton` pattern used by Recipe List and Combined Log screens.

### Current layout
**`bodyweight_screen.dart:19-97`**:
```dart
return SafeArea(
  child: Column(
    children: [
      Padding(
        child: Row(
          children: [
            Text('Bodyweight'),           // title
            Spacer(),
            FilledButton.icon(...),        // ← "+ Log weight" button (line 32-37)
            PopupMenuButton(...),          // CSV export
          ],
        ),
      ),
      Divider(),
      Expanded(child: ListView...),        // body
    ],
  ),
);
```

### Reference pattern (Recipe List, Combined Log)
```dart
return Scaffold(
  appBar: AppBar(title: Text('...'), actions: [...]),
  floatingActionButton: FloatingActionButton(
    onPressed: ...,
    child: Icon(Icons.add),
  ),
  body: ...,
);
```

### Files to change
- `lib/features/bodyweight/bodyweight_screen.dart:19-97`

### Proposed fix
1. Replace `SafeArea` + `Column` with `Scaffold` + `AppBar` + `body`
2. Move title to `AppBar.title`
3. Move `PopupMenuButton` (CSV export) to `AppBar.actions`
4. Replace `FilledButton.icon` with `FloatingActionButton(child: Icon(Icons.add))`
5. Keep `_showSheet()` logic unchanged

### Risk
Medium. Layout restructuring. Need to preserve:
- CSV export `PopupMenuButton` functionality
- Entry tap-to-edit and long-press-to-delete interactions
- `SafeArea` behavior (Scaffold handles this automatically)

---

## G1: Dynamic "Per lb/kg bodyweight" toggle label

### Problem
The protein basis toggle shows "Per lb bodyweight" regardless of whether the user is in metric or imperial mode. Metric users should see "Per kg bodyweight".

### Root Cause
Both screens have hardcoded `const` segment labels:

**`goals_screen.dart:465-472`**:
```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'bodyweight', label: Text('Per lb bodyweight')),
    ButtonSegment(value: 'height', label: Text('Per cm height')),
  ],
  ...
),
```

**`onboarding_screen.dart:486-493`**: Identical hardcoded labels.

Both screens already have a `_useImperial` bool and a `_unitPrefs` getter that correctly computes dynamic units for the slider label, recommended range text, and slider min/max. The toggle segments are the only place where units are hardcoded.

### Existing dynamic pattern (for reference)
**`goals_screen.dart:474-494`** — slider label already uses:
```dart
'Protein: ${_unitPrefs.displayProteinGPerLb(...).toStringAsFixed(1)} ${_unitPrefs.proteinUnitForBasis(_proteinBasis)}'
```

**`unit_preferences_provider.dart:35-38`**:
```dart
String proteinUnitForBasis(String basis) {
  if (basis == 'height') return 'g/cm';
  return useImperial ? 'g/lb' : 'g/kg';
}
```

### Files to change
- `lib/features/goals/goals_screen.dart:465-472`
- `lib/features/onboarding/onboarding_screen.dart:486-493`

### Proposed fix
Remove `const` from `segments` and make the bodyweight label conditional on `_useImperial`:
```dart
segments: [
  ButtonSegment(
    value: 'bodyweight',
    label: Text('Per ${_useImperial ? "lb" : "kg"} bodyweight'),
  ),
  ButtonSegment(value: 'height', label: Text('Per cm height')),
],
```

Note: "Per cm height" is correct for both systems (height is always measured in cm internally), so only the bodyweight label needs changing.

### Risk
Low. Text-only change. The `_useImperial` field already exists and is correctly managed in both screens.

---

## Summary of all changes

| Issue | Files | Lines | Risk |
|---|---|---|---|
| D1 | `maintenance_card.dart` | 12-28, 84-141 | Medium |
| D2 | `database.dart` | 165-174 | Low |
| F1 | `edit_entry_sheet.dart`, `recipe_form_screen.dart` (×2), `manual_food_form.dart` | 4 locations | Low |
| BW1 | `bodyweight_screen.dart` | 19-97 | Medium |
| G1 | `goals_screen.dart`, `onboarding_screen.dart` | 2 locations | Low |
