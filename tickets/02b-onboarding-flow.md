# T2b — Onboarding flow

Multi-field initial setup screen shown on first launch.

## Files to create

- `lib/features/onboarding/onboarding_screen.dart` — scrollable form page

## Files to modify

- `lib/app.dart` — check `onboarding_completed` from `user_goals`; redirect to onboarding or app shell
- `lib/core/database/tables/user_goals.dart` — add DAO methods for profile fields
- `lib/providers/goals_provider.dart` — add profile read/write

## Layout

Single scrollable form page with sections:

### Sex
Segmented button: **Male** / **Female**

### Age
Number text field (years), numeric keyboard

### Height
Number text field (cm), decimal keyboard

### Starting weight
- Number text field (kg), decimal keyboard
- Date picker (defaults to today)
- On save: seeds a `bodyweight_entry` row

### Initial goals
Same fields as T9 goals screen, embedded inline:
- Goal type segmented button (cut / maintain / bulk), default: cut (−500)
- Calorie adjustment number field with rate preview
- Protein g/lb slider (0.5–2.0, range hint 0.8–1.4)
- Fat % slider (10–50%, shaded band 20–35%)

## Behavior

- On launch, if `user_goals.onboarding_completed == 0`, show onboarding before app shell
- Save button validates all required fields, then:
  1. Upserts `user_goals` row with all profile fields + goals + `onboarding_completed = 1`, `updated_at = now`
  2. Inserts `bodyweight_entry` with starting weight + date
  3. Navigates to app shell (replaces onboarding, no back)
- If user presses back during onboarding, show confirmation dialog: "Your progress won't be saved"
- All fields required (starting weight date defaults to today if not changed)

## DAO methods needed

- `Future<UserGoals?> getGoals()` — already added in T9
- `Future<void> upsertGoals(UserGoals goals)` — already added in T9
- `Future<void> insertWeight(BodyweightEntry entry)` — already added in T7

## Acceptance criteria

- Fresh install shows onboarding before app shell
- All fields render with correct input types
- Save persists all fields, navigates to app shell
- Second launch skips onboarding (reads `onboarding_completed = 1`)
- Back press during onboarding shows confirmation dialog

## Testing

- **Widget — full flow**: fill all fields, tap save, verify `user_goals` row has correct values + `onboarding_completed = 1`, verify `bodyweight_entry` inserted
- **Widget — skip on re-launch**: set `onboarding_completed = 1` in DB, launch app, verify app shell renders directly
- **Widget — validation**: tap save with empty fields, error shown on each required field
- **Widget — back confirmation**: tap back, confirmation dialog appears; "Leave" pops, "Stay" dismisses dialog
- **Widget — defaults**: goal type segmented buttons set correct calorie adjustment defaults (−500, 0, +300)
- **Integration — full round-trip**: complete onboarding, kill app, re-launch, app shell appears, goals screen shows saved values
- **Widget — keyboard type**: age uses number keyboard, height uses decimal keyboard, weight uses decimal keyboard

Use `ProviderScope` with in-memory DB. Seed `user_goals` with `onboarding_completed = 0` (default) for first-launch tests.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Fresh install: onboarding screen appears before app shell
- [ ] Fill all fields, tap save — app shell appears
- [ ] Kill + re-launch: app shell appears (no onboarding)
- [ ] Sex segmented button: Male / Female toggle correctly
- [ ] Age, height, weight fields use correct keyboard types
- [ ] Weight date picker defaults to today
- [ ] Initial goals section with goal type, adjustment, protein, fat sliders
- [ ] Back press shows "Discard?" confirmation dialog
- [ ] After onboarding, goals screen shows all saved profile fields + goals
- [ ] First bodyweight entry visible on bodyweight screen / dashboard sparkline
- [ ] All widget tests pass

## Dependencies

T1 (database schema with new columns), T2 (app shell — needs to exist for redirect)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T2b — Onboarding flow | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
