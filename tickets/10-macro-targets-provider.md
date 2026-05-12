# T10 — Macro targets provider

Provider that reads goals + latest bodyweight + maintenance calories and computes daily targets.

## Files to create

- `lib/providers/macro_targets_provider.dart`
- `lib/core/algorithms/mifflin_st_jeor.dart` — standalone pure function, no DB or provider dependencies

## Algorithm

See PLAN.md §4 for full detail.

```
if regression_maintenance != null:
  target_calories = regression_maintenance + adjustment              // Phase 3+4
else if onboarding_completed:
  estimated = estimateMaintenance(sex, weight_kg, height_cm, age)   // Phase 2b
  target_calories = estimated + adjustment
else:
  target_calories = max(adjustment, 1200)                           // pre-onboarding safe floor

protein_g = bodyweight_lb × protein_g_per_lb
fat_cal   = target_calories × (fat_pct / 100)
fat_g     = fat_cal / 9
carbs_cal = target_calories − protein_cal − fat_cal
carbs_g   = carbs_cal / 4
```

The `estimateMaintenance()` function (Mifflin-St Jeor × 1.55) is defined in this
ticket as a standalone pure function in `mifflin_st_jeor.dart`. It is consumed
here directly and also imported by T13 for the maintenance provider's reference.
This avoids a cross-phase dependency: T10 (Phase 3) does not block on T13 (Phase 4).

## Mifflin-St Jeor utility

Create `lib/core/algorithms/mifflin_st_jeor.dart`:

```dart
double estimateMaintenance({
  required String sex,
  required double weightKg,
  required double heightCm,
  required int age,
}) {
  double bmr;
  if (sex == 'male') {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
  } else {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  }
  return bmr * 1.55; // moderate activity
}
```

This is a pure, stateless function with no DB or provider dependencies — it can
be implemented and tested independently of both T10 and T13.

### Mifflin-St Jeor tests

- **Unit — male**: sex=male, weight=80kg, height=178cm, age=30 → BMR = 10×80 + 6.25×178 − 5×30 + 5 = 1757.5, ×1.55 = 2724.1. Verify within 0.1%
- **Unit — female**: sex=female, same inputs → BMR = 10×80 + 6.25×178 − 5×30 − 161 = 1591.5, ×1.55 = 2466.8. Verify within 0.1%
- **Unit — weight changes**: weight=70kg produces lower result than 80kg (all else equal)
- **Unit — height changes**: height=160cm produces lower result than 178cm (all else equal)

## Provider inputs

Watches:
- `goalsProvider` (from T9) — includes sex, height_cm, age, goal_weight_kg, use_imperial, onboarding_completed from user_goals
- `bodyweightProvider` — latest weight in kg, converted to lb
- `maintenanceProvider` (from T13) — may return null; when null, falls back to Mifflin-St Jeor (this ticket) if onboarding completed

## Output

```dart
class MacroTargets {
  final double targetCalories;
  final double proteinGrams;
  final double fatGrams;
  final double carbsGrams;
  final double? maintenanceCalories;  // regression result, or Mifflin-St Jeor estimate, or null
  final double calorieAdjustment;
  final double rateLbsPerWeek;
}
```

## Acceptance criteria

- Provider emits `MacroTargets` with correct values
- Changing goals or bodyweight triggers recalculation
- When regression returns null but onboarding is complete, uses Mifflin-St Jeor × 1.55 as maintenance
- When regression and onboarding data are both absent, uses `max(adjustment, 1200)` as safe floor
- Rate preview value matches `adjustment × 7 / 3500`

## Testing

### MacroTargets unit tests
- **Unit — with regression maintenance**: goals: 500 deficit, 1.0g/lb protein, 25% fat; bodyweight: 80kg (176lb); regression maintenance: 2500. Verify: `targetCalories=2000`, `proteinG=176`, `fatCal=500`, `fatG=55.6`, `carbsCal=796`, `carbsG=199`, `rateLbsPerWeek=-1.0`
- **Unit — Mifflin-St Jeor fallback**: regression = null, onboarding complete, sex=male, height=178cm, age=30, weight=80kg. Verify `targetCalories ≈ mifflin_st_jeor_male × 1.55 + adjustment`
- **Unit — Mifflin-St Jeor female**: same but sex=female, verify different BMR formula used
- **Unit — pre-onboarding safe floor**: regression = null, onboarding not complete. Verify `targetCalories = max(adjustment, 1200)` — e.g. adjustment=-500 → 1200
- **Unit — different bodyweight**: bodyweight = 60kg (132lb) changes protein and fat targets, calories unchanged (same regression maintenance)
- **Unit — rate preview without maintenance**: rate is still computed from `adjustment × 7 / 3500` regardless of maintenance status
- **Unit — fat pct boundary**: fatPct = 50% produces `fatCal = targetCalories × 0.5`
- **Unit — protein boundary**: protein_g_per_lb = 2.0 doubles protein target compared to 1.0
- **Unit — zero adjustment**: goal = maintain (adjustment=0) gives rate = 0 → "Maintenance"

### Mifflin-St Jeor unit tests (in `test/core/algorithms/mifflin_st_jeor_test.dart`)
- **Unit — male**: sex=male, weight=80kg, height=178cm, age=30 → BMR = 10×80 + 6.25×178 − 5×30 + 5 = 1757.5, ×1.55 = 2724.1. Verify within 0.1%
- **Unit — female**: sex=female, same inputs → BMR = 10×80 + 6.25×178 − 5×30 − 161 = 1591.5, ×1.55 = 2466.8. Verify within 0.1%
- **Unit — weight changes**: weight=70kg produces lower result than 80kg (all else equal)
- **Unit — height changes**: height=160cm produces lower result than 178cm (all else equal)

Use Riverpod's `ProviderContainer` directly (no widget tree needed). Override sub-providers with known values, then `container.read(macroTargetsProvider.future)` and assert on the result.

## Human verification

### Macro targets
- [ ] `flutter analyze` passes with zero errors
- [ ] With regression maintenance (2500) + cut (-500): targets = ~2000 cal, ~176g protein, ~56g fat, ~199g carbs
- [ ] Without regression data but onboarding complete: targets computed from Mifflin-St Jeor × 1.55 (e.g., 80kg male, 178cm, 30y → ~2600 + adjustment)
- [ ] Without regression + without onboarding: targets use safe floor `max(adjustment, 1200)` — e.g. cut = 1200 kcal
- [ ] Rate preview: -500 produces "-1.0", +300 produces "0.6", 0 produces "0" — formatting is correct (not "-1.000000")
- [ ] Changing bodyweight from 80kg to 70kg updates protein/fat targets and Mifflin-St Jeor fallback, but not regression-based targets

### Mifflin-St Jeor utility
- [ ] Male: 80kg, 178cm, 30y → ~2724 kcal — verify output matches hand calculation
- [ ] Female: 80kg, 178cm, 30y → ~2467 kcal — verify output matches hand calculation
- [ ] Changing weight/height/age produces proportional changes
- [ ] Function is pure — no DB, no provider, no side effects
- [ ] All unit tests pass via `ProviderContainer` (no widget tree)

## Dependencies

T9 (goals provider with profile fields), T7 (bodyweight provider), T13 (maintenance provider — provides regression result; Mifflin-St Jeor fallback lives in this ticket)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T10 — Macro targets provider | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
