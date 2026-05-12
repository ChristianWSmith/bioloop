# T18 — Data reset option

Allow users to wipe all data and start fresh. Useful during testing/beta and
for users who want to restart their journey.

## Files to create

- `lib/features/settings/settings_screen.dart` — settings screen (or add to an existing screen)

## Files to modify

- `lib/core/database/database.dart` — add a `resetAll()` method that drops and recreates all tables
- `lib/app.dart` — after reset, navigate back to onboarding flow

## Behavior

### Entry point
Add a settings gear icon to the app bar (visible on all screens), or add a
"Settings" option to the dashboard overflow menu. The settings screen contains
a single "Reset All Data" section.

### Reset flow
1. User taps "Reset All Data"
2. Confirmation dialog: "This will delete all your food logs, bodyweight entries, saved foods, and goals. This cannot be undone."
3. After confirming:
   - `resetAll()` truncates all 7 tables (`foods`, `food_entries`, `bodyweight_entries`, `user_goals`, `meal_templates`, `recipes`, `recipe_ingredients`)
   - Navigate back to onboarding flow (same as fresh install — T2b)

### What is preserved
- App theme settings (system-level, not app-managed)
- Nothing else — all app data is in the 7 drift tables

### What is deleted
- All food entries
- All bodyweight entries
- All foods (including seeded, manual, and API-cached)
- All goals and profile settings
- All meal templates
- All recipes and recipe ingredients

## Acceptance criteria

- Settings screen accessible from app (gear icon or overflow menu)
- Tapping "Reset All Data" shows confirmation dialog with clear warning
- Confirming triggers reset + re-onboarding
- All 7 tables are empty after reset (verify via DB inspector)
- Onboarding flow appears after reset (same as fresh install)
- Cancelling the dialog does nothing (safe)
- App does not crash during or after reset

## Testing

- **Widget — settings accessible**: gear icon visible in app bar, tapping opens settings screen
- **Widget — reset confirmation**: tap "Reset All Data", confirmation dialog appears with "This cannot be undone" text
- **Widget — reset cancel**: cancel confirmation, no data deleted
- **Widget — reset + re-onboarding**: confirm reset, verify onboarding screen appears, all DB tables empty
- **Widget — post-reset goals**: complete onboarding after reset, verify user_goals has fresh data (id=1, onboarding_completed=1)
- **Unit — `resetAll()` truncates tables**: insert data into all 7 tables, call `resetAll()`, verify each table has 0 rows
- **Unit — `resetAll()` is idempotent**: call `resetAll()` twice, no crash or error
- **Integration — full cycle**: reset → onboarding → log food → goals set → all flows work as on fresh install

Use in-memory DB for all tests. For the re-onboarding test, simulate app
restart by creating a new `ProviderScope` after reset.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Settings gear icon visible on dashboard
- [ ] Tap "Reset All Data" — confirmation dialog with clear warning appears
- [ ] Cancel — nothing happens (safe cancel)
- [ ] Confirm reset — app navigates to onboarding screen
- [ ] After completing onboarding: dashboard is empty, all data gone
- [ ] Log food + weight after reset — everything works as on fresh install
- [ ] Check DB contents (via debug/inspector) — all 7 tables empty after reset
- [ ] Repeated reset (reset twice) — no crash, works correctly
- [ ] All unit + widget tests pass

## Dependencies

T2b (onboarding — navigated to after reset), T1 (database — provides `resetAll()`)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T18 — Data reset option | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
