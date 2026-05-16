# TKT-6: Remove bodyweight goal feature

**Risk**: High | **Files**: ~12 | **Est**: 4-6hr

---

## Context

The `goalWeightKg` column in `user_goals` is a nullable real that stores an optional target weight. It is surfaced in three screens (onboarding, goals, dashboard) but is **not used by any calculation** — not in maintenance estimation, macro targets, or BMR. Per the product decision, this feature has no value for the app's scope and should be removed entirely.

## Findings

### Database
- `user_goals.dart:13` — `RealColumn get goalWeightKg => real().nullable()();`
- Schema version: 4 (`database.dart:29`)
- Existing migrations show the pattern for `m.deleteColumn` (v2→v3 drops `serving_size_grams` from `foods`)
- `goalWeightKg` is not referenced by any FK or index

### UI (3 screens)
| Screen | File | Lines | What to remove |
|--------|------|-------|----------------|
| Onboarding | `onboarding_screen.dart` | 30, 55, 137-139, 156-158, 190-194, 207-209, 449-466 | Controller, unit conversion, save logic, UI section |
| Goals | `goals_screen.dart` | 28, 58, 79-86, 215-218, 230-233, 253-257, 270-271, 437-452 | Controller, load/save logic, unit conversion, UI field |
| Dashboard | `dashboard_screen.dart` | 81-87, 224-289 | Conditional render, `_buildGoalWeightCard()` method |

### Tests (18 references)
| File | Lines | Change |
|------|-------|--------|
| `test/database_test.dart` | 196-202 | Remove test |
| `test/widget_test.dart` | 201, 243, 954 | Remove/modify 3 assertions |
| `test/features/goals/goals_screen_test.dart` | 311 | Remove assertion |
| `test/features/dashboard/dashboard_screen_test.dart` | 168, 180, 190, 195, 244, 273, 302, 315, 377, 437, 546 | Remove `goalWeightKg` from helper + assertions |
| `test/providers/macro_targets_provider_test.dart` | 33 | Remove field from seed data |

## Acceptance Criteria

- `goalWeightKg` column is removed from the `user_goals` table (schema v5)
- Existing users with `goalWeightKg` data are unaffected (column silently dropped)
- No "Goal weight" UI remains in onboarding, goals, or dashboard screens
- `flutter analyze` passes with zero issues
- `flutter test` passes with all tests updated
- Drift codegen regenerated successfully

## Implementation — Subtasks

### 6a. Database schema + migration

**`lib/core/database/tables/user_goals.dart`** — remove line 13:
```dart
// Remove this entire line:
RealColumn get goalWeightKg => real().nullable()();
```

**`lib/core/database/database.dart`**:
- Bump `schemaVersion` from 4 to 5 (line 29)
- Add to migration (after v4 block):
```dart
if (from < 5) {
  await m.deleteColumn(userGoals, userGoals.goalWeightKg);
}
```

Run:
```bash
dart run build_runner build
```

### 6b. Onboarding screen

**`lib/features/onboarding/onboarding_screen.dart`**:

Remove:
- `_goalWeightController` declaration (line 30)
- `_goalWeightController.dispose()` (line 55)
- Goal weight unit conversion: lines 137-139 (kg→lb on imperial toggle) and 156-158 (lb→kg on metric toggle)
- Goal weight save logic: lines 190-194 (`goalWeightKg = ...`) and 207-209 (`goalWeightKg: Value<double?>`)
- "Goal Weight" UI section: lines 449-466

The `_canSave` getter at line 165 does **not** require goal weight (only birthdate, height, weight), so no change needed there.

### 6c. Goals screen

**`lib/features/goals/goals_screen.dart`**:

Remove:
- `_goalWeightController` declaration (line 28)
- `_goalWeightController.dispose()` (line 58)
- Goal weight load logic: lines 79-86 (populate controller from `goals.goalWeightKg`)
- Goal weight unit conversion: lines 215-218 (kg→lb) and 230-233 (lb→kg)
- Goal weight save logic: lines 253-257 (parse controller) and 270-271 (`goalWeightKg: Value<double?>`)
- "Goal weight (optional)" `TextFormField`: lines 437-452

### 6d. Dashboard screen

**`lib/features/dashboard/dashboard_screen.dart`**:

Remove:
- Conditional `_buildGoalWeightCard()` render: lines 81-87
- Full `_buildGoalWeightCard()` method: lines 224-289
- The `maintenance_card.dart` import is unaffected (maintenance card stays)

### 6e. Tests

**`test/database_test.dart`** — remove test at lines 196-202:
```dart
// Remove:
test('goal_weight_kg is null by default', () async {
  ...
});
```

**`test/widget_test.dart`** — remove/modify assertions at lines 201, 243, 954.

**`test/features/goals/goals_screen_test.dart`** — remove assertion at line 311.

**`test/features/dashboard/dashboard_screen_test.dart`**:
- Remove `goalWeightKg` parameter from `makeGoals()` helper (lines 168, 180, 190, 195)
- Remove/modify test cases that check goal weight card: lines 244, 273, 302, 315, 377, 437, 546
- May need to add a check that the goal weight card is no longer shown

**`test/providers/macro_targets_provider_test.dart`** — remove `goalWeightKg: null` from seed data at line 33.

## Regressions to Watch For

- Widget tests that create `UserGoalsCompanion` with `goalWeightKg` field will fail to compile — must remove the field from all call sites
- The `goals_screen_test.dart` may need to check that the goal weight field is absent from the UI rather than asserting its absence
- Dashboard tests that check `goal weight card shows delta` or `goal weight card hidden when goals null` must be rewritten (goal weight card no longer exists)
- Ensure the `Divider(height: 32)` that follows the goal weight section in onboarding/goals is also removed (or kept if the section below is logically separated)

## Post-implementation verification

```bash
# 1. Regenerate drift code
dart run build_runner build

# 2. Analyze
flutter analyze > analyze.log 2>&1

# 3. Test
flutter test > test.log 2>&1

# 4. Read results
cat analyze.log
cat test.log
```
