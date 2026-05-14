# Ticket 1 — Fix dashboard refresh after goals save

- **Issues:** #4, #5
- **Priority:** High
- **Effort:** Trivial (~1 line)
- **Dependencies:** None

---

## Context

The Goals screen lets the user set protein (g/lb) and fat (% of calories) targets via sliders. When the user taps **Save**, `GoalsScreen._save()` persists the new values to `user_goals` via `db.upsertGoals()`, but does **not** invalidate any Riverpod provider afterward.

The dashboard reads macro targets through the following chain:

```
macroTargetsProvider (FutureProvider<MacroTargets>)
  ├─ goalsProvider.getGoals()       ← reads fresh from DB each invocation
  ├─ bodyweightProvider.future      ← watches resetTriggerProvider
  └─ maintenanceProvider.future     ← watches resetTriggerProvider
```

Since `macroTargetsProvider` is a `FutureProvider` that calls `getGoals()` directly (not via `userGoalsProvider`), it does pick up new DB values on next invocation. But nothing triggers a re-invocation after save, so the dashboard shows stale values until another event causes a rebuild.

Every other data-modifying screen in the app invalidates the relevant provider after save:

| Screen | Action |
|--------|--------|
| Log food | `ref.invalidate(todaysFoodProvider)` |
| Log recipe | `ref.invalidate(todaysFoodProvider)` |
| Bodyweight | `ref.invalidate(bodyweightProvider)` |
| Settings reset | `ref.read(resetTriggerProvider.notifier).state++` |
| Onboarding complete | `ref.invalidate(bodyweightProvider)`, `ref.invalidate(todaysFoodProvider)`, `ref.invalidate(userGoalsProvider)` |

The Goals screen is the only one missing this step.

---

## Proposed fix

Add `ref.invalidate(userGoalsProvider)` in `goals_screen.dart` after `db.upsertGoals()` succeeds.

**Location:** `lib/features/goals/goals_screen.dart`, line 269 (after the `try` block's `upsertGoals` call, before the success snackbar).

```dart
await db.upsertGoals(...);
ref.invalidate(userGoalsProvider);  // ← add this
if (mounted) {
  setState(() => _saving = false);
  ...
```

**Why `userGoalsProvider` and not `resetTriggerProvider`:** Targeted invalidation is lighter. `resetTriggerProvider` would unnecessarily re-fetch bodyweight and maintenance data too.

**Invalidation cascade:**

```
ref.invalidate(userGoalsProvider)
  → userGoalsProvider re-fetches from DB
  → macroTargetsProvider: goalsProvider.getGoals() reads fresh goals
  → macroTargetsProvider recomputes proteinGrams, fatGrams, carbsGrams
  → DashboardScreen: ref.watch(macroTargetsProvider) rebuilds MacroRing widgets
```

---

## Acceptance criteria

1. Open Goals screen → change the protein slider → Save → navigate to Dashboard → targets reflect new protein value
2. Open Goals screen → change the fat slider → Save → navigate to Dashboard → targets reflect new fat value
3. Open Goals screen → change both → Save → Dashboard reflects both changes
4. Other providers (bodyweight, maintenance, today's food) are **not** unnecessarily re-fetched

---

## Testing

### Unit/integration test approach

```dart
testWidgets('saving goals invalidates macroTargetsProvider', (tester) async {
  final db = AppDatabase.createInMemory();
  addTearDown(() => db.close());

  // Seed: onboarding goals + bodyweight entry
  await db.into(db.userGoals).insert(UserGoalsCompanion(
    goalType: const Value('cut'),
    calorieAdjustment: const Value<double?>(-500),
    proteinGPerLb: const Value(1.0),
    fatCaloriePct: const Value(25.0),
    onboardingCompleted: const Value(1),
    ...
  ));
  await db.into(db.bodyweightEntries).insert(BodyweightEntriesCompanion(...));

  // Build app with Goals screen
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: GoalsScreen()),
    ),
  );
  await tester.pumpAndSettle();

  // Move protein slider (or verify initial macroTargets)
  // Save
  // Verify macroTargetsProvider emits updated values
});
```

Key assertion: after saving with `proteinGPerLb = 1.5`, `ref.read(macroTargetsProvider).proteinGrams` should reflect `weightLb × 1.5`.

---

## Files touched

| File | Change |
|------|--------|
| `lib/features/goals/goals_screen.dart:269` | Add `ref.invalidate(userGoalsProvider)` |
