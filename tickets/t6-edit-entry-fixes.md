# T6: Fix edit entry sheet — wording, rounding, stale dashboard

## Status

| Field | Value |
|-------|-------|
| Priority | High |
| Complexity | Trivial |
| Files changed | 1 |
| Lines changed | 4 |
| Risk | Low — isolated to `edit_entry_sheet.dart` |

## Context

Three bugs in `lib/features/history/widgets/edit_entry_sheet.dart`, all in the same file:

1. **Wording (line 162):** Label reads `'Servings (${widget.entry.servingLabel})'` — produces `Servings (g)`, confusing. Should be `Quantity (g)`.
2. **Rounding (line 36):** `e.servings.toString()` produces raw double strings like `2.3333333333333335` in the text field. Macro fields already use `toStringAsFixed(1)` (line 67–70) but the servings field doesn't.
3. **Stale dashboard (line 107):** Save handler only pops the sheet — never invalidates `todaysFoodProvider` or increments `dataTriggerProvider`. Every other mutation site in the app does both.

## Intent

Fix all three bugs. The edit drawer should show sensible labels, rounded values, and trigger dashboard/maintenance refresh on save.

## Changes

**File:** `lib/features/history/widgets/edit_entry_sheet.dart`

| # | Location | Current | Fix |
|---|----------|---------|-----|
| 1 | Line 36 | `e.servings.toString()` | `e.servings.toStringAsFixed(1)` |
| 2 | Line 162 | `'Servings (${widget.entry.servingLabel})'` | `'Quantity (${widget.entry.servingLabel})'` |
| 3 | After line 107 | *(none)* | `ref.invalidate(todaysFoodProvider);` + `ref.read(dataTriggerProvider.notifier).state++;` |

The provider invalidation matches the pattern used in `quick_food_log_sheet.dart:92–96`, `log_food_screen.dart:161–162`, etc.

## Testing

- New widget test: open `EditEntrySheet` with known entry → assert servings field shows `toStringAsFixed(1)` value
- New widget test: edit servings → save → assert `todaysFoodProvider` is invalidated (watch count increments)
- Existing tests should continue to pass (255/255)
- `flutter analyze` — zero issues

## Dependencies

None. Independent of T7 and T8.
