# T11 — Dashboard: today's summary + progress rings

Widgets showing today's logged macros vs targets.

## Files to create

- `lib/features/dashboard/widgets/macro_ring.dart` — circular progress ring widget

## Files to modify

- `lib/features/dashboard/dashboard_screen.dart` — wire up real content

## Components

### Calorie ring
Large circular progress ring:
- Outer ring: calories consumed / target calories
- Center text: "1,450 / 2,000 kcal"
- Below: remaining (or over) in kcal

### Macro rings
Three smaller rings in a row (protein, fat, carbs):
- Each shows consumed / target in grams
- Color-coded: protein = blue, fat = orange, carbs = green

## Provider needed

- `todaysFoodProvider` — aggregates `food_entries` for today, exposes `List<FoodEntry>` + `Map<String, double>` totals

## Data flow

```
dashboard_screen
  ├─ todaysFoodProvider      → consumed totals
  ├─ macroTargetsProvider    → targets (from T10)
  └─ renders macro_ring × 4
```

## Acceptance criteria

- Rings render with correct consumed/target values after logging food
- Empty day shows 0 / target
- Rings animate on change
- Over-consumption shown with overflow styling (red)

## Dependencies

T6 (food entries), T10 (macro targets)
