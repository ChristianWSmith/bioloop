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

## Testing

- **Widget — validation**: submit with empty name shows error; submit with all valid fields succeeds
- **Widget — save**: fill valid form, tap save, verify `Food` is created with `source = 'manual'` and `barcode = null`
- **Widget — cancel**: tap back/cancel, verify no DB writes occurred and pop returns null
- **Widget — optional gram weight**: leaving the gram field empty does not block save; entering a value stores it
- **Widget — field defaults**: all macro fields start empty (no pre-fill), serving label placeholder is "e.g. 1 cup, 1 slice"
- **Integration**: food created via form is returned by `FoodSearchProvider.searchByName()`

Use `ProviderScope` overrides to inject a real in-memory drift database so widget tests can verify persistence.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Open the form on emulator — all fields render with correct labels and placeholders
- [ ] Tap save with empty fields — validation errors show on required fields
- [ ] Fill valid data, save — entry appears in local food search results
- [ ] "Serving size in grams" is optional — save without it, then with it; both persist correctly
- [ ] `source` is `'manual'`, `barcode` is `null` — verify in DB
- [ ] All widget tests pass (especially save + cancel flows)
- [ ] Form handles keyboard dismissal and scroll correctly when keyboard covers fields

## Dependencies

T4 (foods DAO)
