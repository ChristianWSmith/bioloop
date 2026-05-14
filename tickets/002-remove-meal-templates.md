# Ticket 2 — Remove meal templates feature

- **Issues:** #6, #8
- **Priority:** Medium
- **Effort:** Medium (~9 files, careful deletion)
- **Dependencies:** Must be done **before** Ticket 3 (both modify `log_food_screen.dart`; early removal reduces Ticket 3 scope)

---

## Context

The meal templates feature stores JSON-snapshot lists of foods under a user-chosen name, saved/loaded via a bottom sheet drawer. The feature is:

- **Redundant** (issue #8) — the same workflow is covered by recents + manual re-logging
- **Bugged** (issue #6) — drawer always shows "No templates yet" even when templates exist, likely due to a silent parsing error in `_parseTemplateFoods()` or a schema issue

Rather than fix the bugs, the feature should be removed entirely.

---

## Proposed fix

### Files to delete (3)

| File | Lines | Contents |
|------|-------|----------|
| `lib/features/logging/widgets/meal_templates.dart` | 266 | `TemplateFood` data class, `MealTemplatesSheet` widget, `saveCurrentFoodsAsTemplate()` function |
| `lib/core/database/tables/meal_templates.dart` | 8 | `MealTemplates` drift table definition |
| `test/features/logging/meal_templates_test.dart` | 350 | Tests for the deleted feature |

### Files to edit (5+)

#### `lib/core/database/database.dart`
- Remove `import` of `meal_templates.dart` table (near line 10)
- Remove DAO methods (lines ~241–265):
  - `insertTemplate()`
  - `getAllTemplates()`
  - `getTemplate()`
  - `updateTemplate()`
  - `deleteTemplate()`
- Remove `mealTemplates` reference in `resetAll()` transaction (line 374)

#### `lib/features/logging/log_food_screen.dart`
- Remove `import 'widgets/meal_templates.dart'` (line 14)
- Remove `_onSaveAsTemplate()` method (lines 76–100)
- Remove `_openTemplates()` method (lines 102–149)
- Remove bookmark button widget in build (lines 305–311, key: `save_as_template_button`)
- Remove "Templates" button widget in build (lines 341–348, key: `templates_button`)

#### `lib/core/database/database.g.dart` (generated Drift code)
- Regenerate after removing table: `dart run build_runner build`

#### `test/features/settings/settings_test.dart`
- Remove `meal_templates` case from `countTable()` switch (lines 74–75)
- Remove template seed data from `createSeedDb()` (lines 43–47)
- Remove template assertions from reset tests (lines 94, 104, 213)

#### `test/database_test.dart`
- Remove the `meal_templates: insert and read back` test block (lines 124–138)

#### `AGENTS.md`
- In "Key conventions → Drift": change "7 tables" to "6 tables" and remove `meal_templates` from the list
- In "Design rules": remove the "Meal templates" bullet (currently line 95)
- In "Important notes": remove meal_templates references if any

---

## Acceptance criteria

1. Project compiles with zero errors (`flutter analyze` passes)
2. All existing tests pass (`flutter test` passes)
3. No imports or references to `meal_templates`, `MealTemplatesSheet`, `TemplateFood`, `saveCurrentFoodsAsTemplate`, `_onSaveAsTemplate`, or `_openTemplates` remain
4. The "Templates" button no longer appears on the Log screen
5. The bookmark icon no longer appears next to the search field on the Log screen
6. `resetAll()` no longer references `mealTemplates`
7. Drift generated code (`database.g.dart`) regenerates cleanly

## Testing

- Remove the dedicated `meal_templates_test.dart` file
- Update `settings_test.dart` to remove template references
- Update `database_test.dart` to remove template test
- Run `flutter test` to confirm remaining tests pass
- Run `flutter analyze` to confirm zero issues

---

## Risks

- **Missed references**: grep the entire repo for `meal_template`, `saveAsTemplate`, `TemplateFood` etc. after edits to ensure nothing is left dangling
- **Drift codegen**: the generated `.g.dart` file references the table type; running `build_runner` is required and may produce diffs
- **log_food_screen.dart rework**: this is the most delicate file — removing the bookmark and templates buttons changes the layout row. Verify the row still looks correct with just the barcode scan button and Recipes button.
