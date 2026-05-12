# T5 — Manual food creation form

Form for users to create custom foods that only exist in their local database.

## Files to create

- `lib/features/logging/widgets/manual_food_form.dart` — form widget or full-screen page

## Form fields

| Field | Type | Validation |
|-------|------|------------|
| Name | Text | Required, non-empty |
| Serving label | Text | Required, e.g. "1 cup", "1 slice" |
| Calories per serving | Number | Required, ≥ 0 |
| Protein per serving (g) | Number | Required, ≥ 0 |
| Carbs per serving (g) | Number | Required, ≥ 0 |
| Fat per serving (g) | Number | Required, ≥ 0 |
| Serving size in grams (optional) | Number | ≥ 0, nullable |

## Behavior

- Save sets `source = 'manual'`, `barcode = null`, `created_at = now`
- On successful save, return the created `Food` object to the caller (log screen navigates back with it selected)
- Form can be opened from the log screen as a "+ Custom Food" option in the search bar

## Acceptance criteria

- Form validates all required fields
- Save writes to `foods` table with correct `source`
- Saved food appears in subsequent local searches
- Cancelling returns null / pops without saving

## Dependencies

T4 (foods DAO)
