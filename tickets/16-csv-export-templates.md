# T16 — CSV export + meal templates

Two related features grouped as a future polish ticket.

## Part A — CSV export

`lib/features/history/export.dart`

- Export `food_entries` to CSV: date, meal type, name, servings, calories, protein, carbs, fat
- Export `bodyweight_entries` to CSV: date, weight_kg
- Use `share_plus` package to trigger system share sheet
- Accessible from history screen (overflow menu) and bodyweight screen

## Part B — Meal templates

`lib/features/logging/widgets/meal_templates.dart`

A "template" is a saved named collection of one or more `food_entries`.
- Save current meal as template (from log screen) — stores macro snapshots
- Quick-add from templates (on log screen, "Templates" button) — all template foods added to today's log in one tap
- CRUD via `meal_templates` table

### Schema: `meal_templates` table

The table is already created in T1 (see PLAN.md §1 for DDL). This ticket defines **DAO methods and CRUD logic** only:
- `Future<int> insertTemplate(MealTemplate template)` — insert new template
- `Future<List<MealTemplate>> getAllTemplates()` — return all templates
- `Future<MealTemplate?> getTemplate(int id)`
- `Future<void> updateTemplate(MealTemplate template)` — update name or foods JSON
- `Future<void> deleteTemplate(int id)`

- `foods` JSON: each entry stores a frozen macro snapshot of a food entry (name, calories, protein_g, carbs_g, fat_g, servings, serving_label).

## Acceptance criteria

- CSV export produces valid CSV files that open in spreadsheet app
- Share sheet opens with the CSV file attached
- Can save current meal as a named template
- Can browse and add a template's foods to today's log in one tap
- Can delete templates

## Testing

### CSV export
- **Unit — food CSV format**: 3 food entries produce CSV with header + 3 data rows; fields match: date, meal_type, name, servings, calories, protein_g, carbs_g, fat_g
- **Unit — weight CSV format**: 2 weight entries produce CSV with header + 2 rows; fields: date, weight_kg
- **Unit — empty export**: no entries → CSV with header row only
- **Unit — special characters**: food name with commas is quoted in CSV

### Meal templates
- **Widget — save template**: log a meal with 2 foods, tap "Save as template", enter name, verify template saved
- **Widget — add from template**: tap "Templates" on log screen, select a template, all foods added to today's log
- **Widget — delete template**: long-press a template, confirm delete, template removed from list

## Human verification

### CSV export
- [ ] `flutter analyze` passes with zero errors
- [ ] From History screen, tap overflow menu → "Export CSV" — share sheet opens with CSV file
- [ ] CSV opens correctly in spreadsheet app (Numbers, Excel, Google Sheets) — columns delimited properly
- [ ] Food names containing commas are properly quoted in CSV
- [ ] Empty export produces CSV with header row only (not an empty file or error)
- [ ] Bodyweight CSV export works from bodyweight screen

### Meal templates
- [ ] Log a meal with 2+ foods, tap "Save as template" — name the template, it saves
- [ ] Next log session: tap "Templates" → saved template appears
- [ ] Select the template → all template foods added to today's log in one tap
- [ ] Long-press a template → delete with confirmation — template removed
- [ ] All unit + widget tests pass

## Dependencies

T1 (meal_templates table already exists), T6 (food entries), T8 (history screen)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T16 — CSV export + meal templates | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
