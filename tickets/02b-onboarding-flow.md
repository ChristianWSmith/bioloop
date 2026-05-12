# T2b — Onboarding flow

Multi-field initial setup screen shown on first launch.

## Files to create

- `lib/features/onboarding/onboarding_screen.dart` — scrollable form page
- `lib/providers/onboarding_provider.dart` — read/write `user_goals` for onboarding (separate from T9's goals_provider to avoid cross-phase dependency)

## Files to modify

- `lib/app.dart` — check `onboarding_completed` from `user_goals`; redirect to onboarding or app shell
- `lib/core/database/tables/user_goals.dart` — add DAO methods (getGoals, upsertGoals) for the profile fields defined in PLAN.md schema

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

### Goal weight (optional)
- Number text field (kg), decimal keyboard
- Prompt: "What's your target bodyweight?"
- Leave empty to skip (null in DB)

### Display units
- Segmented button: **Metric (kg, cm)** / **Imperial (lb, ft/in)**
- Default: Metric
- Maps to `user_goals.use_imperial` (0 = metric, 1 = imperial)

### Activity level
Segmented button or radio group with 5 levels. Each shows label + heuristic:

| Level | Label | Heuristic |
|-------|-------|-----------|
| 1 | Sedentary | Little to no exercise, desk job |
| 2 | Lightly active | Light exercise 1–3 days/week |
| 3 | Moderately active | Moderate exercise 3–5 days/week |
| 4 | Active | Hard exercise 6–7 days/week |
| 5 | Extra active | Very hard exercise + physical job |

- Default: 3 (Moderately active)
- Stored as `user_goals.activity_level` (1–5)
- Used as the Mifflin-St Jeor activity multiplier when the app falls back to the formula (before sufficient regression data)
- No effect once the rolling regression has enough data

### Initial goals
Same fields as T9 goals screen, embedded inline:
- Goal type segmented button (cut / maintain / bulk), default: cut (−500)
- Calorie adjustment number field with rate preview
- Protein g/lb slider (0.5–2.0, range hint 0.8–1.4)
- Fat % slider (10–50%, shaded band 20–35%)

## Behavior

- On launch, if `user_goals.onboarding_completed == 0`, show onboarding before app shell
- Save button validates all required fields, then:
  1. Upserts `user_goals` row with all profile fields + `goal_weight_kg` (nullable) + `use_imperial` + `activity_level` + goals + `onboarding_completed = 1`, `updated_at = now`
  2. Inserts `bodyweight_entry` with starting weight + date
  3. Navigates to app shell (replaces onboarding, no back)
- If user presses back during onboarding, show confirmation dialog: "Your progress won't be saved"
- All fields required except goal weight (optional) and date (defaults to today)

## DAO methods needed

Add to `lib/core/database/tables/user_goals.dart` (created in T1):
- `Future<UserGoals?> getGoals()` — fetch singleton row
- `Future<void> upsertGoals(UserGoals goals)` — insert or replace by id=1

Add to `lib/core/database/tables/bodyweight_entries.dart` (created in T1):
- `Future<void> insertWeight(BodyweightEntry entry)` — insert a bodyweight log row

## Acceptance criteria

- Fresh install shows onboarding before app shell
- All fields render with correct input types
- Goal weight is optional (can be left empty)
- Units toggle defaults to metric, persists correctly
- Save persists all fields, navigates to app shell
- Second launch skips onboarding (reads `onboarding_completed = 1`)
- Back press during onboarding shows confirmation dialog

## Testing

- **Widget — full flow**: fill all fields (including goal weight, imperial toggle, activity level), tap save, verify `user_goals` row has correct values + `goal_weight_kg` stored + `use_imperial = 1` + `activity_level` stored + `onboarding_completed = 1`, verify `bodyweight_entry` inserted
- **Widget — skip goal weight**: leave goal weight empty, tap save, verify `goal_weight_kg` is null in DB
- **Widget — units default**: verify `use_imperial` defaults to 0 (metric)
- **Widget — activity level default**: verify `activity_level` defaults to 3 (moderate)
- **Widget — activity level selection**: select level 5 (extra active), save, verify DB stores `activity_level = 5`
- **Widget — skip on re-launch**: set `onboarding_completed = 1` in DB, launch app, verify app shell renders directly
- **Widget — validation**: tap save with empty required fields, error shown on each
- **Widget — back confirmation**: tap back, confirmation dialog appears; "Leave" pops, "Stay" dismisses dialog
- **Widget — defaults**: goal type segmented buttons set correct calorie adjustment defaults (−500, 0, +300)
- **Integration — full round-trip**: complete onboarding (metric), kill app, re-launch, app shell appears, goals screen shows saved values in metric
- **Widget — keyboard type**: age uses number keyboard, height uses decimal keyboard, weight uses decimal keyboard

Use `ProviderScope` with in-memory DB. Seed `user_goals` with `onboarding_completed = 0` (default) for first-launch tests.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Fresh install: onboarding screen appears before app shell
- [ ] Fill all fields (including goal weight, imperial toggle, activity level), tap save — app shell appears
- [ ] Goal weight left empty: save still succeeds, field is null in DB
- [ ] Units toggle: Metric default; switching to Imperial and saving sets `use_imperial = 1`
- [ ] Activity level defaults to 3 (Moderately active); selecting level 1 (Sedentary) stores 1; selects level 5 (Extra active) stores 5
- [ ] Kill + re-launch: app shell appears (no onboarding)
- [ ] Sex segmented button: Male / Female toggle correctly
- [ ] Age, height, weight fields use correct keyboard types
- [ ] Weight date picker defaults to today
- [ ] Initial goals section with goal type, adjustment, protein, fat sliders
- [ ] Back press shows "Discard?" confirmation dialog
- [ ] After onboarding, goals screen shows all saved profile fields + goal weight + units + activity level + goals
- [ ] First bodyweight entry visible on bodyweight screen / dashboard sparkline
- [ ] All widget tests pass

## Dependencies

T1 (database schema with all columns), T2 (app shell — needs to exist for redirect)

Note: The `user_goals` and `bodyweight_entries` DAO methods used in onboarding are defined *in this ticket*, not in later tickets. Do not defer them to T7 or T9.

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T2b — Onboarding flow | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
