# T10 — Macro targets provider

Provider that reads goals + latest bodyweight + maintenance calories and computes daily targets.

## Files to create

- `lib/providers/macro_targets_provider.dart`

## Algorithm

See PLAN.md §4 for full detail.

```
target_calories = maintenance + adjustment  (or just adjustment if maintenance null)
protein_g       = bodyweight_lb × protein_g_per_lb
fat_cal         = target_calories × (fat_pct / 100)
fat_g           = fat_cal / 9
carbs_cal       = target_calories − protein_cal − fat_cal
carbs_g         = carbs_cal / 4
```

## Provider inputs

Watches:
- `goalsProvider` (from T9)
- `bodyweightProvider` — latest weight in kg, converted to lb
- `maintenanceProvider` (from T13) — may return null

## Output

```dart
class MacroTargets {
  final double targetCalories;
  final double proteinGrams;
  final double fatGrams;
  final double carbsGrams;
  final double? maintenanceCalories;
  final double calorieAdjustment;
  final double rateLbsPerWeek;
}
```

## Acceptance criteria

- Provider emits `MacroTargets` with correct values
- Changing goals or bodyweight triggers recalculation
- Works correctly when maintenance is null (fallback to adjustment as absolute total)
- Rate preview value matches `adjustment × 7 / 3500`

## Testing

- **Unit — with maintenance**: goals: 500 deficit, 1.0g/lb protein, 25% fat; bodyweight: 80kg (176lb); maintenance: 2500. Verify: `targetCalories=2000`, `proteinG=176`, `fatCal=500`, `fatG=55.6`, `carbsCal=796`, `carbsG=199`, `rateLbsPerWeek=-1.0`
- **Unit — without maintenance**: same inputs but maintenance = null. Verify `targetCalories=500` (absolute floor), protein/fat/carbs scale down proportionally
- **Unit — different bodyweight**: bodyweight = 60kg (132lb) changes protein and fat targets, calories unchanged
- **Unit — rate preview without maintenance**: rate is still computed from `adjustment × 7 / 3500` regardless of maintenance status
- **Unit — fat pct boundary**: fatPct = 50% produces `fatCal = targetCalories × 0.5`
- **Unit — protein boundary**: protein_g_per_lb = 2.0 doubles protein target compared to 1.0
- **Unit — zero adjustment**: goal = maintain (adjustment=0) gives rate = 0 → "Maintenance"

Use Riverpod's `ProviderContainer` directly (no widget tree needed). Override sub-providers with known values, then `container.read(macroTargetsProvider.future)` and assert on the result.

## Dependencies

T9 (goals provider), T7 (bodyweight provider), T13 (maintenance provider — use a stub that returns null initially)
