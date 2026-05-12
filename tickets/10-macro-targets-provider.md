# T10 — Macro targets provider

Provider that reads goals + latest bodyweight + maintenance calories and computes daily targets.

## Files to create

- `lib/providers/macro_targets_provider.dart`

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

The `estimateMaintenance()` function (Mifflin-St Jeor × 1.55) is defined in T13
and consumed here when the regression algorithm has insufficient data.

## Provider inputs

Watches:
- `goalsProvider` (from T9) — includes sex, height_cm, age, onboarding_completed from user_goals
- `bodyweightProvider` — latest weight in kg, converted to lb
- `maintenanceProvider` (from T13) — may return null; when null, falls back to Mifflin-St Jeor if onboarding completed

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

- **Unit — with regression maintenance**: goals: 500 deficit, 1.0g/lb protein, 25% fat; bodyweight: 80kg (176lb); regression maintenance: 2500. Verify: `targetCalories=2000`, `proteinG=176`, `fatCal=500`, `fatG=55.6`, `carbsCal=796`, `carbsG=199`, `rateLbsPerWeek=-1.0`
- **Unit — Mifflin-St Jeor fallback**: regression = null, onboarding complete, sex=male, height=178cm, age=30, weight=80kg. Verify `targetCalories ≈ mifflin_st_jeor_male × 1.55 + adjustment`
- **Unit — Mifflin-St Jeor female**: same but sex=female, verify different BMR formula used
- **Unit — pre-onboarding safe floor**: regression = null, onboarding not complete. Verify `targetCalories = max(adjustment, 1200)` — e.g. adjustment=-500 → 1200
- **Unit — different bodyweight**: bodyweight = 60kg (132lb) changes protein and fat targets, calories unchanged (same regression maintenance)
- **Unit — rate preview without maintenance**: rate is still computed from `adjustment × 7 / 3500` regardless of maintenance status
- **Unit — fat pct boundary**: fatPct = 50% produces `fatCal = targetCalories × 0.5`
- **Unit — protein boundary**: protein_g_per_lb = 2.0 doubles protein target compared to 1.0
- **Unit — zero adjustment**: goal = maintain (adjustment=0) gives rate = 0 → "Maintenance"

Use Riverpod's `ProviderContainer` directly (no widget tree needed). Override sub-providers with known values, then `container.read(macroTargetsProvider.future)` and assert on the result.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] With regression maintenance (2500) + cut (-500): targets = ~2000 cal, ~176g protein, ~56g fat, ~199g carbs
- [ ] Without regression data but onboarding complete: targets computed from Mifflin-St Jeor × 1.55 (e.g., 80kg male, 178cm, 30y → ~2600 + adjustment)
- [ ] Without regression + without onboarding: targets use safe floor `max(adjustment, 1200)` — e.g. cut = 1200 kcal
- [ ] Rate preview: -500 produces "-1.0", +300 produces "0.6", 0 produces "0" — formatting is correct (not "-1.000000")
- [ ] Changing bodyweight from 80kg to 70kg updates protein/fat targets and Mifflin-St Jeor fallback, but not regression-based targets
- [ ] All unit tests pass via `ProviderContainer` (no widget tree)
- [ ] **⚠ Critical check**: Mifflin-St Jeor estimate is within reasonable range — 80kg male, 178cm, 30y → BMR ≈ 1755, ×1.55 ≈ 2720. Verify with known test data.

## Dependencies

T9 (goals provider with profile fields), T7 (bodyweight provider), T13 (maintenance provider + estimateMaintenance function)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T10 — Macro targets provider | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
