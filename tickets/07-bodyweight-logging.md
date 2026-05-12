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

## Dependencies

T1 (database)
