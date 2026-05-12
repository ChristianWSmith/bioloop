# T7 — Bodyweight logging

Bottom sheet for logging bodyweight.

## Files to create

- `lib/features/bodyweight/widgets/add_weight_sheet.dart`

## Files to modify

- `lib/features/bodyweight/bodyweight_screen.dart` — wire up the sheet + show existing entries
- `lib/providers/bodyweight_provider.dart` — insert + query `bodyweight_entries`

## AddWeightSheet layout

| Field | Type | Default |
|-------|------|---------|
| Date | Date picker | Today |
| Weight (kg/lb) | Text input with numeric keyboard | Empty |

- Tap "Log weight" → validates → inserts → pops
- Optional: quick-preset buttons for common weights nearby if we have prior data
- When opened from edit (existing entry tapped): pre-fills current weight and date, title changes to "Edit weight", button reads "Update"
- On edit save: updates `weight_kg` and/or `logged_at` in-place (no new row)
- Weight label shows "kg" or "lb" depending on `user_goals.use_imperial` (default kg if goals not yet loaded)

## DAO methods needed

- `Future<void> insertWeight(BodyweightEntry entry)`
- `Future<void> updateWeight(BodyweightEntry entry)` — updates weight_kg and/or logged_at by id
- `Future<List<BodyweightEntry>> getWeights({int? limit, DateTime? since})`

## Acceptance criteria

- Can open sheet from bodyweight tab
- Can enter weight + date and save
- Saved entry appears in a simple list on the bodyweight screen
- Can tap an existing entry to edit weight and/or date
- Can delete an entry via long-press
- Provider exposes `AsyncValue<List<BodyweightEntry>>` sorted by date desc

## Testing

- **Widget — sheet opens**: tapping "Log weight" on bodyweight screen shows bottom sheet
- **Widget — validation**: empty weight shows error; non-numeric input shows error
- **Widget — save**: enter valid weight and date, tap "Log weight", sheet closes, entry appears in list below
- **Widget — edit**: tap an existing entry, sheet opens pre-filled with current weight and date, title is "Edit weight", button reads "Update"
- **Widget — edit save**: change weight, tap "Update", sheet closes, entry reflects new weight in list, no new row created
- **Widget — delete**: long-press an entry, tap delete in confirmation dialog, entry removed from list and DB
- **Widget — keyboard type**: weight text field uses numeric keyboard (`TextInputType.numberWithOptions(decimal: true)`)
- **Unit — provider sorting**: `bodyweightProvider` returns entries sorted by `logged_at` descending
- **Integration — date backfill**: logging a weight for yesterday does not affect today's list, but appears in the full query

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Tap "Log weight" on bodyweight tab — bottom sheet opens with date picker + weight field
- [ ] Date picker defaults to today
- [ ] Weight field uses numeric decimal keyboard and displays correct unit label (kg or lb)
- [ ] Enter weight, tap "Log weight" — sheet closes, entry appears in list below
- [ ] Tap an existing entry — sheet opens pre-filled, title says "Edit weight", button says "Update"
- [ ] Change weight in edit mode, tap "Update" — list reflects change, no duplicate row
- [ ] Long-press an entry → delete confirmation → entry removed
- [ ] Empty state (no entries) shows an appropriate message
- [ ] Log weights on different dates — list sorts descending by date
- [ ] All widget + unit tests pass
- [ ] Quick-preset buttons (optional): if implemented, verify they show nearby values based on prior data

## Dependencies

T1 (database)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T7 — Bodyweight logging | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
