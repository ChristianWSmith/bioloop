# T16 — CSV export + meal templates + recipe builder

Three related features grouped as a future polish ticket.

## Part A — CSV export

`lib/features/history/export.dart`

- Export `food_entries` to CSV: date, meal type, name, servings, calories, protein, carbs, fat
- Export `bodyweight_entries` to CSV: date, weight_kg
- Use `share_plus` package to trigger system share sheet
- Accessible from history screen (overflow menu) and bodyweight screen

## Part B — Meal templates + recipe builder

- `lib/features/logging/widgets/meal_templates.dart`

### Meal templates

A "template" is a saved named collection of one or more `food_entries`.
- Save current meal as template (from log screen)
- Quick-add from templates (on log screen, "Templates" button)
- CRUD via a simple templates table

### Recipe builder

A "recipe" is a named composite dish with ingredient-level quantities. When logged, it inserts all ingredient foods as separate `food_entries` (each with scaled macros).
- **Create recipe**: from the log screen, tap "New Recipe" → name the recipe → add foods with quantities from the food search/manual form (same flow as logging, but targets a recipe instead of today's log)
- **Log recipe**: from the Templates/Recipes list, select a recipe → all ingredient entries are added to today's log in one tap (same as template)
- **Edit recipe**: tap an existing recipe to adjust ingredient quantities or add/remove ingredients
- **Delete recipe**: long-press → confirmation → removed

The distinction from templates: a template saves exact macro snapshots of a meal you already logged; a recipe lets you compose a dish from raw ingredients and log it repeatedly. Both share the same underlying storage.

### Schema: `meal_templates` table

```sql
CREATE TABLE meal_templates (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  type        TEXT NOT NULL DEFAULT 'template',  -- 'template' | 'recipe'
  foods       TEXT NOT NULL,       -- JSON array of {food_id?, name, serving_label, servings, calories, protein_g, ...}
  created_at  TEXT NOT NULL
);
```

- `type = 'template'`: exact snapshot of a logged meal (macro values frozen)
- `type = 'recipe'`: ingredient list that can be scaled (macro values recomputed when serving size changes)
- `foods` JSON: each entry stores enough info to insert into `food_entries` directly. If `food_id` is present, the recipe can reference the `foods` table for scaling.

## Acceptance criteria

- CSV export produces valid CSV files that open in spreadsheet app
- Share sheet opens with the CSV file attached
- Can save current meal as a named template
- Can browse and add a template's foods to today's log in one tap
- Can create a recipe by composing ingredients with quantities
- Can log a recipe (adds all ingredients to today's log)
- Can edit recipe ingredients and quantities
- Can delete templates and recipes

## Testing

### CSV export
- **Unit — food CSV format**: 3 food entries produce CSV with header + 3 data rows; fields match: date, meal_type, name, servings, calories, protein_g, carbs_g, fat_g
- **Unit — weight CSV format**: 2 weight entries produce CSV with header + 2 rows; fields: date, weight_kg
- **Unit — empty export**: no entries → CSV with header row only
- **Unit — special characters**: food name with commas is quoted in CSV

### Meal templates
- **Widget — save template**: log a meal with 2 foods, tap "Save as template", enter name, verify template saved with `type = 'template'`
- **Widget — add from template**: tap "Templates" on log screen, select a template, all foods added to today's log
- **Widget — delete template**: long-press a template, confirm delete, template removed from list

### Recipe builder
- **Widget — create recipe**: tap "New Recipe", enter name, add 2 foods with quantities, save, recipe appears in list with `type = 'recipe'`
- **Widget — log recipe**: select a recipe from the list, all ingredient entries added to today's log with scaled macros
- **Widget — edit recipe**: tap an existing recipe, change an ingredient quantity, save, recipe updates
- **Widget — delete recipe**: long-press a recipe, confirm delete, recipe removed
- **Unit — template JSON round-trip**: serialize a meal with 3 foods to JSON, deserialize, verify all macro values match
- **Unit — recipe macro scaling**: recipe ingredient with `servings: 2` produces double the macros of `servings: 1`

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

### Recipe builder
- [ ] Tap "New Recipe" → enter name → search and add 3 ingredients with quantities → save
- [ ] Recipe appears in Templates/Recipes list with a "Recipe" badge (separate from plain templates)
- [ ] Select the recipe → all 3 ingredients logged to today's log with correct scaled macros
- [ ] Edit the recipe → change a quantity → save → log again → macros reflect the change
- [ ] Long-press a recipe → delete with confirmation — recipe removed
- [ ] All unit + widget tests pass

## Dependencies

T6 (food entries), T7 (bodyweight entries), T8 (history screen), T4 (food search for ingredient selection)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T16 — CSV export + meal templates + recipe builder | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
