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

## Dependencies

T9 (goals provider), T7 (bodyweight provider), T13 (maintenance provider — use a stub that returns null initially)
