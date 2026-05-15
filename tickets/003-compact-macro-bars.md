# 003 — Compact macro bars on the log screen

**Issues**: #7
**Files**:
- New: `lib/features/logging/widgets/macro_bars.dart`
- Modify: `lib/features/logging/combined_log_screen.dart`

**Effort**: Medium

---

## Context

The log screen currently shows food entries grouped by meal type but has no quick summary of the day's macro totals. The user has to navigate to the Dashboard to see progress. We need a compact macro display above the food entries that shows horizontal progress bars (not rings) for a quick status glance.

Design:
```
┌──────────────────────────────────────┐
│ Calories     1,800 / 2,500 kcal  ████░░│  ← full width
└──────────────────────────────────────┘
┌────────────┬────────────┬────────────┐
│ Protein     │ Carbs       │ Fat         │
│ 120 / 150 g │ 200 / 300 g │ 50 / 80 g   │
│ ████░░      │ █████░░     │ ████░░      │  ← 1/3 width each
└────────────┴────────────┴────────────┘
```

---

## Data sources

The log screen already watches `dateFoodProvider(_currentDate)` which provides `List<FoodEntry>` for the selected date. Consumed macros can be computed via `.fold()` on this list, identical to what `DashboardScreen` does at lines 66-69:

```dart
final consumedCals = entries.fold(0.0, (s, e) => s + e.calories);
final consumedProtein = entries.fold(0.0, (s, e) => s + e.proteinGrams);
final consumedFat = entries.fold(0.0, (s, e) => s + e.fatGrams);
final consumedCarbs = entries.fold(0.0, (s, e) => s + e.carbsGrams);
```

Macro targets come from `macroTargetsProvider`. Add this watch to `CombinedLogScreen.build()`.

Colors (matching the Dashboard):
- Calories → `Theme.of(context).colorScheme.primary`
- Protein → `Colors.blue`
- Carbs → `Colors.green`
- Fat → `Colors.orange`

---

## Acceptance criteria

1. A compact macro bar display appears above all food entries in the log screen's ListView
2. Calories shown as a full-width horizontal bar showing consumed/target
3. Protein, Carbs, Fat shown below as three equal-width bars (1/3 of screen each)
4. All values update reactively when entries are added, edited, or deleted
5. When there are no entries, the bars show 0 consumed with targets still visible
6. The widget does not interfere with swipe-to-delete, date navigation, or any other log screen functionality
7. Works on both today's date view and past date views

---

## Implementation notes

Create `MacroBars` as a `ConsumerWidget` or `StatelessWidget` that takes consumed macros and targets as parameters.

Add it to `CombinedLogScreen` in the `ListView` builder, before the loop over `sortedMeals` (around line 301). Wrap it in a `Padding` and `Card` for visual consistency.

The bars should use simple `ClipRRect` + `LinearProgressIndicator` or custom painted containers — no animations needed.

Refresh behavior is already handled: `QuickFoodLogSheet._log()` calls `ref.invalidate(todaysFoodProvider)` which causes `dateFoodProvider(_currentDate)` to re-fetch, which rebuilds `MacroBars`.

---

## Testing

1. Log a food entry → verify macro bars appear above the entries
2. Log multiple entries → verify totals accumulate correctly
3. Navigate to a past date → verify bars reflect that date's entries
4. Delete an entry → verify totals decrease
5. Edit an entry → verify totals update
6. Run `flutter analyze` — zero issues
