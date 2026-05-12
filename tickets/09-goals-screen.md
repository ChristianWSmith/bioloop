# T9 — Goals configuration screen

Screen where users set their goal type, calorie adjustment, and macro preferences.

## Files to modify

- `lib/features/goals/goals_screen.dart` — full implementation
- `lib/providers/goals_provider.dart` — read/write `user_goals` (uses existing DAOs from T2b)

## Layout

### Profile (editable fields from onboarding)
- **Sex**: segmented button (Male / Female)
- **Age**: number text field (years)
- **Height**: number text field (cm/ft-in depending on units toggle)
- **Goal weight**: number text field, optional (kg/lb depending on units toggle)
  - Leave empty for no target
  - When set, dashboard shows delta from current bodyweight
- **Display units**: segmented button **Metric (kg, cm)** / **Imperial (lb, ft/in)**
  - When imperial: height shows ft + in fields, weight shows lb, goal weight shows lb
  - Stored as `user_goals.use_imperial` (0 = metric, 1 = imperial)
- **Activity level**: segmented button or radio group with 5 levels (same labels + heuristics as T2b)
  - Default: 3 (Moderately active)
  - Each option shows label + heuristic (e.g. "Active — Hard exercise 6–7 days/week")
  - Affects Mifflin-St Jeor fallback maintenance; no effect once regression is active
  - Stored as `user_goals.activity_level` (1–5)
- All pre-filled from `user_goals`, included in upsert on save

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
- "Save" button at bottom; backs out to dashboard. Only one row exists (`id = 1`), upserted on save.
- **Save button is disabled if any required field (age, height, sex) is empty** — prevent, don't validate after.
- On DB write failure: error dialog per PLAN.md §6.

## DAO methods needed

Already added in T2b (no new DAO work needed here):
- `Future<UserGoals?> getGoals()` — fetch singleton
- `Future<void> upsertGoals(UserGoals goals)` — includes `goal_weight_kg`, `use_imperial`, and `activity_level` fields

## Provider
- `goalsProvider` — reads current goals
- `updateGoalsProvider` — notifier to save changes, triggers recompute of macro targets

## Acceptance criteria
- Profile fields (sex, age, height, goal weight) editable, persist correctly
- Goal weight is optional, can be cleared
- Units toggle switches between metric and imperial display for all weight/height fields
- Activity level selector renders 5 levels with heuristics, defaults to 3 (moderate)
- Can select goal type, defaults populate correctly
- Rate preview updates live as adjustment changes
- Protein and fat sliders work, show correct values
- Save persists and is readable after restart
- Carbs section shows "Fills remaining calories"

## Testing

- **Widget — profile fields**: sex segmented button toggles, age and height fields accept numeric input and pre-fill from DB
- **Widget — goal weight**: goal weight field accepts numeric input, shows correct unit label (kg or lb), leaving empty stores null
- **Widget — units toggle**: switching to imperial converts height display to ft+in fields and weight to lb; switching back to metric reverts to cm and kg
- **Widget — units persistence**: set units to imperial, save, reopen screen — units still show imperial
- **Widget — activity level selector**: activity level selector renders 5 options with heuristics, default is 3 (moderate)
- **Widget — activity level save**: change activity level to 1, save, reopen screen, shows 1 (sedentary)
- **Widget — profile save**: profile fields (including goal_weight_kg, use_imperial, and activity_level) are included in the upsert and readable after re-launch
- **Widget — goal type defaults**: cut selects -500, maintain selects 0, bulk selects +300
- **Widget — rate preview**: adjustment = -500 shows "~1 lb/week loss"; -1000 shows "~2 lb/week loss"; +350 shows "~0.7 lb/week gain"
- **Widget — protein slider**: slider moves between 0.5 and 2.0; current value displayed above
- **Widget — fat slider**: slider moves between 10 and 50; current % and gram equivalent ("35% = 78g") displayed
- **Widget — carbs display**: shows "Fills remaining calories" (not a user input)
- **Widget — save + persist**: tap Save, pop back, reopen screen, all values match what was saved
- **Widget — save disabled when required fields empty**: clear age field, verify Save button is disabled
- **Widget — save error shows dialog**: inject a DB write failure, tap Save, verify error dialog appears
- **Unit — DAO upsert**: calling `upsertGoals()` twice with id=1 updates in place, `getGoals()` returns latest
- **Unit — DAO empty state**: `getGoals()` returns null when table is empty (no row inserted yet)

Widget tests should use `ProviderScope` with in-memory DB and mock `bodyweightProvider` (for rate display that depends on weight).

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] Profile section renders with sex (Male/Female), age, height, goal weight, and activity level pre-filled from DB
- [ ] Goal weight field shows correct unit label (kg or lb); leaving empty is allowed
- [ ] Units toggle: switching to imperial changes height to ft+in fields, weight to lb; switching back reverses
- [ ] Activity level: 5 options with heuristics visible, default is 3 (Moderately active); changing and saving persists
- [ ] Editing profile fields (including goal weight, units, and activity level) and saving persists them
- [ ] Profile fields are nullable until onboarding completed
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
T1 (database with profile columns), T2 (app shell), T2b (onboarding — profile fields seed the DB)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T9 — Goals configuration screen | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
