# T16 — CSV export + meal templates

Two separate features grouped as a future polish ticket.

## Part A — CSV export

`lib/features/history/export.dart`

- Export `food_entries` to CSV: date, meal type, name, servings, calories, protein, carbs, fat
- Export `bodyweight_entries` to CSV: date, weight_kg
- Use `share_plus` package to trigger system share sheet
- Accessible from history screen (overflow menu) and bodyweight screen

## Part B — Meal templates

- `lib/features/logging/widgets/meal_templates.dart`

A "template" is a saved named collection of one or more `food_entries`.
- Save current meal as template (from log screen)
- Quick-add from templates (on log screen, "Templates" button)
- CRUD via a simple templates table or just stored in a JSON file

### Schema option 1: `meal_templates` table (recommended)

```sql
CREATE TABLE meal_templates (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  name      TEXT NOT NULL,
  foods     TEXT NOT NULL,       -- JSON array of {name, calories, protein_g, ...}
  created_at TEXT NOT NULL
);
```

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
- **Unit — template JSON round-trip**: serialize a meal with 3 foods to JSON, deserialize, verify all macro values match

## Dependencies

T6 (food entries), T7 (bodyweight entries), T8 (history screen)
