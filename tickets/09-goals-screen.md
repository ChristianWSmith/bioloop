# T9 — Goals configuration screen

Screen where users set their goal type, calorie adjustment, and macro preferences.

## Files to modify

- `lib/features/goals/goals_screen.dart` — full implementation
- `lib/core/database/tables/user_goals.dart` — add DAO methods
- `lib/providers/goals_provider.dart` — read/write `user_goals`

## Layout

### Goal type
Segmented button: **Cut** / **Maintain** / **Bulk**

### Calorie adjustment
- Number input field
- Default: -500 (cut), 0 (maintain), +300 (bulk)
- Live rate preview below: *"~1 lb/week loss"* (uses `adjustment × 7 / 3500`)

### Protein
- Slider 0.5–2.0 g/lb bodyweight
- Range indicator displayed as shaded region 0.8–1.4
- Current value shown above slider

### Fat
- Slider 10–50% of calories
- Shaded healthy band 20–35%
- Current % and gram equivalent shown above

### Carbs
- Display-only: "Fills remaining calories"
- Automatically computed

### Save
"Save" button at bottom; backs out to dashboard. Only one row exists (`id = 1`), upserted on save.

## DAO methods needed
- `Future<UserGoals?> getGoals()` — fetch singleton
- `Future<void> upsertGoals(UserGoals goals)`

## Provider
- `goalsProvider` — reads current goals
- `updateGoalsProvider` — notifier to save changes, triggers recompute of macro targets

## Acceptance criteria
- Can select goal type, defaults populate correctly
- Rate preview updates live as adjustment changes
- Protein and fat sliders work, show correct values
- Save persists and is readable after restart
- Carbs section shows "Fills remaining calories"

## Testing

- **Widget — goal type defaults**: cut selects -500, maintain selects 0, bulk selects +300
- **Widget — rate preview**: adjustment = -500 shows "~1 lb/week loss"; -1000 shows "~2 lb/week loss"; +350 shows "~0.7 lb/week gain"
- **Widget — protein slider**: slider moves between 0.5 and 2.0; current value displayed above
- **Widget — fat slider**: slider moves between 10 and 50; current % and gram equivalent ("35% = 78g") displayed
- **Widget — carbs display**: shows "Fills remaining calories" (not a user input)
- **Widget — save + persist**: tap Save, pop back, reopen screen, all values match what was saved
- **Unit — DAO upsert**: calling `upsertGoals()` twice with id=1 updates in place, `getGoals()` returns latest
- **Unit — DAO empty state**: `getGoals()` returns null when table is empty (no row inserted yet)

Widget tests should use `ProviderScope` with in-memory DB and mock `bodyweightProvider` (for rate display that depends on weight).

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Goal type segmented button: tapping Cut sets adjustment to -500, Maintain to 0, Bulk to +300
- [ ] Adjustment field editable — changing -500 to -800 updates rate preview to "~1.6 lb/week loss"
- [ ] Rate preview updates live as the adjustment field changes (not just on save)
- [ ] Protein slider: drag between 0.5–2.0, value display updates, range indicator 0.8–1.4 visible
- [ ] Fat slider: drag between 10–50, % display updates, gram equivalent ("35% = 78g") updates based on bodyweight
- [ ] Carbs section shows "Fills remaining calories" (not an input)
- [ ] Save persists: change values, save, navigate away, come back — all values match
- [ ] First launch: empty state shows defaults (cut, -500, protein=1.0, fat=25%)
- [ ] All widget + unit tests pass

## Dependencies
T1 (database), T2 (placeholder exists)
