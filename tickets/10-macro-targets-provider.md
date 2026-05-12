# T10 — Macro targets provider

Provider that reads goals + latest bodyweight + maintenance calories and computes daily targets.

## Files to create

- `lib/providers/macro_targets_provider.dart`
- `lib/providers/maintenance_provider.dart` — **stub** that always returns `AsyncValue(null)`. Replaced by T13's real implementation in Phase 4. Exists here so that `macroTargetsProvider` can reference it without a Phase 4 dependency.
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

The `estimateMaintenance()` function (Mifflin-St Jeor × activity multiplier) is
defined in this ticket as a standalone pure function in `mifflin_st_jeor.dart`.
It is consumed here directly and also imported by T13 for the maintenance
provider's reference. This avoids a cross-phase dependency: T10 (Phase 3) does
not block on T13 (Phase 4).

## Mifflin-St Jeor utility

Create `lib/core/algorithms/mifflin_st_jeor.dart`:

```dart
const List<double> _activityMultipliers = [1.2, 1.375, 1.55, 1.725, 1.9];

double estimateMaintenance({
  required String sex,
  required double weightKg,
  required double heightCm,
  required int age,
  int activityLevel = 3, // 1–5, default 3 = moderate
}) {
  final clamped = activityLevel.clamp(1, 5);
  final double bmr;
  if (sex == 'male') {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
  } else {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  }
  return bmr * _activityMultipliers[clamped - 1];
}
```

The multiplier lookup table:

| `activityLevel` | Label | Multiplier |
|----------------|-------|-----------|
| 1 | Sedentary | 1.2 |
| 2 | Lightly active | 1.375 |
| 3 | Moderately active (default) | 1.55 |
| 4 | Active | 1.725 |
| 5 | Extra active | 1.9 |

This is a pure, stateless function with no DB or provider dependencies — it can
be implemented and tested independently of both T10 and T13.

### Mifflin-St Jeor tests

- **Unit — male default (moderate)**: sex=male, weight=80kg, height=178cm, age=30 → BMR = 10×80 + 6.25×178 − 5×30 + 5 = 1757.5, ×1.55 = 2724.1. Verify within 0.1%
- **Unit — female default (moderate)**: sex=female, same inputs → BMR = 10×80 + 6.25×178 − 5×30 − 161 = 1591.5, ×1.55 = 2466.8. Verify within 0.1%
- **Unit — sedentary**: activityLevel=1 → multiplier 1.2 → result lower than default
- **Unit — extra active**: activityLevel=5 → multiplier 1.9 → result higher than default
- **Unit — activity level clamping**: activityLevel=0 clamps to 1, activityLevel=7 clamps to 5
- **Unit — weight changes**: weight=70kg produces lower result than 80kg (all else equal)
- **Unit — height changes**: height=160cm produces lower result than 178cm (all else equal)

## Provider inputs

Watches:
- `goalsProvider` (from T9) — includes sex, height_cm, age, goal_weight_kg, use_imperial, activity_level, onboarding_completed from user_goals
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
- When regression returns null but onboarding is complete, uses Mifflin-St Jeor × activity_level multiplier as maintenance
- When regression and onboarding data are both absent, uses `max(adjustment, 1200)` as safe floor
- Rate preview value matches `adjustment × 7 / 3500`

## Testing

### MacroTargets unit tests
- **Unit — with regression maintenance**: goals: 500 deficit, 1.0g/lb protein, 25% fat; bodyweight: 80kg (176lb); regression maintenance: 2500. Verify: `targetCalories=2000`, `proteinG=176`, `fatCal=500`, `fatG=55.6`, `carbsCal=796`, `carbsG=199`, `rateLbsPerWeek=-1.0`
- **Unit — Mifflin-St Jeor fallback (default moderate)**: regression = null, onboarding complete, sex=male, height=178cm, age=30, weight=80kg, activity_level=3. Verify `targetCalories ≈ 2724 + adjustment`
- **Unit — Mifflin-St Jeor fallback (sedentary)**: activity_level=1, same inputs → target lower than default
- **Unit — Mifflin-St Jeor fallback (extra active)**: activity_level=5, same inputs → target higher than default
- **Unit — Mifflin-St Jeor female**: same but sex=female, verify different BMR formula used
- **Unit — pre-onboarding safe floor**: regression = null, onboarding not complete. Verify `targetCalories = max(adjustment, 1200)` — e.g. adjustment=-500 → 1200
- **Unit — different bodyweight**: bodyweight = 60kg (132lb) changes protein and fat targets, calories unchanged (same regression maintenance)
- **Unit — rate preview without maintenance**: rate is still computed from `adjustment × 7 / 3500` regardless of maintenance status
- **Unit — fat pct boundary**: fatPct = 50% produces `fatCal = targetCalories × 0.5`
- **Unit — protein boundary**: protein_g_per_lb = 2.0 doubles protein target compared to 1.0
- **Unit — zero adjustment**: goal = maintain (adjustment=0) gives rate = 0 → "Maintenance"

### Mifflin-St Jeor unit tests (in `test/core/algorithms/mifflin_st_jeor_test.dart`)
- **Unit — male default (moderate)**: sex=male, weight=80kg, height=178cm, age=30 → BMR = 10×80 + 6.25×178 − 5×30 + 5 = 1757.5, ×1.55 = 2724.1. Verify within 0.1%
- **Unit — female default (moderate)**: sex=female, same inputs → BMR = 10×80 + 6.25×178 − 5×30 − 161 = 1591.5, ×1.55 = 2466.8. Verify within 0.1%
- **Unit — sedentary**: activityLevel=1 → multiplier 1.2 → result lower than default
- **Unit — extra active**: activityLevel=5 → multiplier 1.9 → result higher than default
- **Unit — activity level clamping**: activityLevel=0 clamps to 1, activityLevel=7 clamps to 5
- **Unit — weight changes**: weight=70kg produces lower result than 80kg (all else equal)
- **Unit — height changes**: height=160cm produces lower result than 178cm (all else equal)

Use Riverpod's `ProviderContainer` directly (no widget tree needed). Override sub-providers with known values, then `container.read(macroTargetsProvider.future)` and assert on the result.

## Human verification

### Macro targets
- [ ] `flutter analyze` passes with zero errors
- [ ] With regression maintenance (2500) + cut (-500): targets = ~2000 cal, ~176g protein, ~56g fat, ~199g carbs
- [ ] Without regression data but onboarding complete (activity_level=3): targets computed from Mifflin-St Jeor × 1.55 (e.g., 80kg male, 178cm, 30y → ~2600 + adjustment)
- [ ] Changing activity level (e.g. from 3/moderate to 1/sedentary) lowers estimated maintenance by the correct multiplier ratio
- [ ] Without regression + without onboarding: targets use safe floor `max(adjustment, 1200)` — e.g. cut = 1200 kcal
- [ ] Rate preview: -500 produces "-1.0", +300 produces "0.6", 0 produces "0" — formatting is correct (not "-1.000000")
- [ ] Changing bodyweight from 80kg to 70kg updates protein/fat targets and Mifflin-St Jeor fallback, but not regression-based targets

### Mifflin-St Jeor utility
- [ ] Male, default activity: 80kg, 178cm, 30y → ~2724 kcal — verify output matches hand calculation
- [ ] Female, default activity: 80kg, 178cm, 30y → ~2467 kcal — verify output matches hand calculation
- [ ] Changing activity level 1→5 produces proportional multiplier changes (1.2 → 1.9)
- [ ] Clamping: activityLevel=0 behaves as sedentry, activityLevel=7 behaves as extra active
- [ ] Changing weight/height/age produces proportional changes
- [ ] Function is pure — no DB, no provider, no side effects
- [ ] All unit tests pass via `ProviderContainer` (no widget tree)

## Dependencies

T9 (goals provider with profile fields), T7 (bodyweight provider)

Note: This ticket creates a stub `maintenanceProvider` that always returns `null`. T13 (Phase 4) will replace it with the real regression-based implementation. The `macroTargetsProvider` handles the null case by falling back to Mifflin-St Jeor.

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T10 — Macro targets provider | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
