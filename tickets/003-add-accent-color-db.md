# Ticket 3: Add Accent Color Preference to Database

**Priority:** Medium  
**Complexity:** Low  
**Estimated effort:** 10 minutes + drift generation time  
**Files:** `lib/core/database/tables/user_goals.dart`

---

## Description

Add a column to the `user_goals` table to store the user's preferred accent color seed value as an integer (ARGB).

---

## Context

From `DISCOVERY.md`:

> The app currently hardcodes `Colors.deepPurple` in `lib/theme/theme.dart`. To support user customization, we need to persist the color preference in the database.

**Why store as int?**
- Flutter `Color` objects can be converted to/from int via `color.value` and `Color(intValue)`
- Drift supports `IntColumn` natively
- Nullable column allows default behavior when no color is set

**Schema version:** 1 (no migration needed — app not published yet)

---

## Acceptance Criteria

- [ ] New column `accentColorSeed` added to `UserGoals` table
- [ ] Column type is `IntColumn`, nullable
- [ ] Default value is `null` (uses `Colors.deepPurple` fallback)
- [ ] Drift generated code compiles without errors
- [ ] No migration strategy needed (schema v1, onCreate only)
- [ ] Existing code continues to work (backward compatible)

---

## Implementation

**File:** `lib/core/database/tables/user_goals.dart`

**Current table definition:**
```dart
class UserGoals extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get goalType => text()();
  RealColumn get calorieAdjustment => real().nullable()();
  RealColumn get proteinGPerLb => real().withDefault(const Constant(1.0))();
  RealColumn get fatCaloriePct => real().withDefault(const Constant(25.0))();
  TextColumn get sex => text().nullable()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get birthdate => text().nullable()();
  IntColumn get age => integer().nullable()();
  IntColumn get useImperial => integer().withDefault(const Constant(0))();
  IntColumn get activityLevel => integer().withDefault(const Constant(3))();
  IntColumn get onboardingCompleted => integer().withDefault(const Constant(0))();
  TextColumn get updatedAt => text()();
}
```

**Add new column:**
```dart
class UserGoals extends Table {
  // ... existing columns ...
  IntColumn get accentColorSeed => integer().nullable()();
  TextColumn get updatedAt => text()();
}
```

**Regenerate drift code:**
```bash
dart run build_runner build
```

---

## Testing Plan

### Verification
- [ ] Run `dart run build_runner build` — completes without errors
- [ ] Check `lib/core/database/database.g.dart` — contains `accentColorSeed` in generated code
- [ ] Run `flutter analyze > analyze.log 2>&1` and read `analyze.log` — zero issues
- [ ] Run `flutter test > test.log 2>&1` and read `test.log` — all tests pass

### Manual Testing (after Ticket 4-5 complete)
1. Open app, go to Settings
2. Change accent color
3. Restart app
4. **Expected:** New color persists

---

## Dependencies

None — this ticket is independent, but required for Tickets 4 and 5.

---

## Notes

- No migration needed since app hasn't been published
- Existing `user_goals` rows will have `null` for this column (default behavior)
- When reading, `null` should be interpreted as "use default deepPurple"
- This is a schema-only change — no business logic modified
