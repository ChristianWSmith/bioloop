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

## Testing

- **Widget — rings render**: macro ring widget renders with consumed = 500, target = 2000, shows "500 / 2,000 kcal" in center
- **Widget — empty day**: with no entries, all rings show 0 / target
- **Widget — partial fill**: protein ring: consumed = 50g, target = 176g, fills to ~28%
- **Widget — over-consumption**: calories exceeded turns ring red, remaining shows negative ("-200 over")
- **Widget — ring animation**: ring animates from 0 to fill on first load (verify via `tester.pumpAndSettle`)
- **Widget — individual macro rings**: protein=blue, fat=orange, carbs=green ring colors
- **Unit — `todaysFoodProvider`**: insert 3 entries for today, 1 for yesterday, provider emits only today's 3 with correct aggregate totals
- **Unit — aggregate math**: `todaysFoodProvider` sums calories, protein_grams, carbs_grams, fat_grams independently

Widget tests override `todaysFoodProvider` and `macroTargetsProvider` with known values to isolate ring rendering.

## Dependencies

T6 (food entries), T10 (macro targets)
