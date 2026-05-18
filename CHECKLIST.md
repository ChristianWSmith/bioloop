# Implementation Checklist

Track progress across all tickets. Do not mark a ticket complete until `flutter analyze` passes with zero issues.

## Tickets

| # | Ticket | File | Status |
|---|--------|------|--------|
| 1 | [D2: Calories sparkline includes today](tickets/D2-calories-sparkline-includes-today.md) | `lib/core/database/database.dart` | ⬜ Pending |
| 2 | [G1: Dynamic protein toggle label](tickets/G1-dynamic-protein-toggle-label.md) | `lib/features/goals/goals_screen.dart`, `lib/features/onboarding/onboarding_screen.dart` | ⬜ Pending |
| 3 | [F1: Whole number quantity formatting](tickets/F1-whole-number-formatting.md) | `edit_entry_sheet.dart`, `recipe_form_screen.dart`, `manual_food_form.dart` | ⬜ Pending |
| 4 | [D1: Maintenance progress alignment](tickets/D1-maintenance-progress-alignment.md) | `lib/features/dashboard/widgets/maintenance_card.dart` | ⬜ Pending |
| 5 | [BW1: Bodyweight FAB](tickets/BW1-bodyweight-fab.md) | `lib/features/bodyweight/bodyweight_screen.dart` | ⬜ Pending |

## Suggested Execution Order

1. **D2** — Smallest change, validates DB query fix
2. **G1** — Zero risk, quick win
3. **F1** — Low risk, 4 similar changes
4. **D1** — Most complex, tackle after simpler tickets
5. **BW1** — Layout restructuring, save for last

Tickets 1–3 are independent and can be done in parallel. Tickets 4 and 5 are also independent of each other and of 1–3.

## Per-Ticket Checklist

### D2: Calories sparkline includes today
- [ ] Change `end` → `end.add(const Duration(days: 1))` in `getEntriesForDateRange()`
- [ ] Verify sparkline shows today's data
- [ ] Verify no regression in other callers
- [ ] `flutter analyze` passes

### G1: Dynamic protein toggle label
- [ ] Update `goals_screen.dart` toggle segments
- [ ] Update `onboarding_screen.dart` toggle segments
- [ ] Verify label changes on metric/imperial toggle
- [ ] `flutter analyze` passes

### F1: Whole number quantity formatting
- [ ] Fix `edit_entry_sheet.dart:39`
- [ ] Fix `recipe_form_screen.dart:89`
- [ ] Fix `recipe_form_screen.dart:130`
- [ ] Fix `manual_food_form.dart:40`
- [ ] Verify whole numbers show without ".0"
- [ ] Verify fractional values still show correctly
- [ ] `flutter analyze` passes

### D1: Maintenance progress alignment
- [ ] Delete `_countDataDaysProvider`
- [ ] Refactor `_buildInsufficientData()` to use `maintenanceProvider`
- [ ] Verify progress bar shows paired data points
- [ ] Verify today is excluded from count
- [ ] `flutter analyze` passes

### BW1: Bodyweight FAB
- [ ] Restructure to Scaffold + AppBar + FAB
- [ ] Move CSV export to AppBar actions
- [ ] Verify FAB opens add-weight sheet
- [ ] Verify CSV export still works
- [ ] Verify entry interactions (tap edit, long-press delete)
- [ ] `flutter analyze` passes

## Post-Implementation

- [ ] Run full test suite: `flutter test > test.log 2>&1`
- [ ] Verify zero test failures
- [ ] Run full analysis: `flutter analyze > analyze.log 2>&1`
- [ ] Verify zero analysis issues
