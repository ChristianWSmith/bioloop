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

## Dependencies
T1 (database), T2 (placeholder exists)
