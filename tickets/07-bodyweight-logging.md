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
| Weight (kg) | Text input with numeric keyboard | Empty |

- Tap "Log weight" → validates → inserts → pops
- Optional: quick-preset buttons for common weights nearby if we have prior data

## DAO methods needed

- `Future<void> insertWeight(BodyweightEntry entry)`
- `Future<List<BodyweightEntry>> getWeights({int? limit, DateTime? since})`

## Acceptance criteria

- Can open sheet from bodyweight tab
- Can enter weight + date and save
- Saved entry appears in a simple list on the bodyweight screen
- Can delete an entry via long-press
- Provider exposes `AsyncValue<List<BodyweightEntry>>` sorted by date desc

## Testing

- **Widget — sheet opens**: tapping "Log weight" on bodyweight screen shows bottom sheet
- **Widget — validation**: empty weight shows error; non-numeric input shows error
- **Widget — save**: enter valid weight and date, tap "Log weight", sheet closes, entry appears in list below
- **Widget — delete**: long-press an entry, tap delete in confirmation dialog, entry removed from list and DB
- **Widget — keyboard type**: weight text field uses numeric keyboard (`TextInputType.numberWithOptions(decimal: true)`)
- **Unit — provider sorting**: `bodyweightProvider` returns entries sorted by `logged_at` descending
- **Integration — date backfill**: logging a weight for yesterday does not affect today's list, but appears in the full query

## Dependencies

T1 (database)
