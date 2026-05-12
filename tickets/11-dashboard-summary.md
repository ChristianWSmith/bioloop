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

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Log a food, navigate to Dashboard — calorie ring shows "525 / 2,000 kcal" (or whatever the targets are)
- [ ] Three macro rings show protein=blue, fat=orange, carbs=green
- [ ] Empty day shows all rings at 0
- [ ] Exceed a macro target (e.g. log 250g protein when target is 176g) — ring turns red, remaining shows negative
- [ ] Rings animate smoothly on first render
- [ ] `todaysFoodProvider` correctly excludes yesterday's entries
- [ ] All widget + unit tests pass
- [ ] No layout overflow — rings resize for different screen widths (small phone vs tablet)

## Dependencies

T6 (food entries), T10 (macro targets)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T11 — Dashboard: summary + progress rings | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
