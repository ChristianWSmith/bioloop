# 001 — Replace age with birthdate

- **Phase**: 1 — Database Schema Changes
- **Priority**: High

## Overview

During onboarding, the user should enter their birthdate instead of their current age. Age should be computed dynamically from the birthdate whenever it's needed for calculations (Mifflin-St Jeor BMR estimator, maintenance calculator). This avoids the age becoming stale over time.

## Context from Discovery

- `UserGoals` table (`lib/core/database/tables/user_goals.dart:10`) stores `IntColumn get age`.
- Onboarding screen (`lib/features/onboarding/onboarding_screen.dart`) has a `TextFormField` for age.
- Goals screen (`lib/features/goals/goals_screen.dart`) has the same age field.
- Mifflin-St Jeor (`lib/core/algorithms/mifflin_st_jeor.dart:4`) receives `age` as a parameter.
- Callers of Mifflin-St Jeor pass age from `UserGoals.age` — the providers `maintenance_provider.dart` and `macro_targets_provider.dart`, as well as the goals screen's fat gram preview.
- Birthdate means: we store an ISO date string (`yyyy-MM-dd`), and whenever we need age, we compute `DateTime.now().difference(birthdate).inDays ~/ 365.25`.

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/database/tables/user_goals.dart` | Add `TextColumn get birthdate` (nullable, no default). Keep `age` column for backward compat during migration, or drop it. |
| `lib/core/database/database.dart` | Update `upsertGoals()` companion to include `birthdate`. No migration needed (in-memory test DB + fresh installs only). |
| `lib/features/onboarding/onboarding_screen.dart` | Replace age `TextFormField` with a date picker for birthdate (range: ~100 years ago to ~12 years ago). Store ISO string. |
| `lib/features/goals/goals_screen.dart` | Same replacement: birthdate picker instead of age field. |
| `lib/core/algorithms/mifflin_st_jeor.dart` | Change `age` parameter to accept birthdate string, compute age internally. |
| `lib/providers/macro_targets_provider.dart` | Update call to Mifflin-St Jeor to pass birthdate. |
| `lib/providers/maintenance_provider.dart` | Update call to Mifflin-St Jeor to pass birthdate. |
| `lib/features/goals/goals_screen.dart` | Update `_estimatedFatGrams` computation to use birthdate. |

## Acceptance Criteria

- [ ] Onboarding asks for birthdate (date picker) instead of age
- [ ] Goals screen asks for birthdate (date picker) instead of age
- [ ] All Mifflin-St Jeor calculations derive age from birthdate at call time
- [ ] Age is never stored as a static value in the database
- [ ] Backward compatible: existing DB rows without birthdate don't crash (default to 30 or show as unset)
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass; new tests cover birthdate→age computation

## Testing

- Unit test: birthdate → age computation (accounting for leap years, boundary dates)
- Provider test: `macro_targets_provider` computes correct age from birthdate
- Widget test: onboarding birthdate picker renders and selection populates the field
- Widget test: goals birthdate picker renders and selection populates the field
