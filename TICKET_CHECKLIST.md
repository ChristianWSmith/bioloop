# bioloop — Ticket checklist

Use this file to track progress across all open tickets. Mark items as `[x]` when complete.

---

## Ticket 1 — Fix dashboard refresh after goals save

- [ ] Edit `lib/features/goals/goals_screen.dart` — add `ref.invalidate(userGoalsProvider)` after `db.upsertGoals()` succeeds (line ~269)
- [ ] Run `flutter analyze` — zero issues
- [ ] Run `flutter test` — all pass

---

## Ticket 2 — Remove meal templates feature

### Delete files
- [ ] Delete `lib/features/logging/widgets/meal_templates.dart`
- [ ] Delete `lib/core/database/tables/meal_templates.dart`
- [ ] Delete `test/features/logging/meal_templates_test.dart`

### Edit `lib/core/database/database.dart`
- [ ] Remove `meal_templates` import (line ~10)
- [ ] Remove DAO methods: `insertTemplate`, `getAllTemplates`, `getTemplate`, `updateTemplate`, `deleteTemplate` (lines ~241–265)
- [ ] Remove `mealTemplates` from `resetAll()` transaction (line ~374)

### Edit `lib/features/logging/log_food_screen.dart`
- [ ] Remove `import 'widgets/meal_templates.dart'` (line 14)
- [ ] Remove `_onSaveAsTemplate()` method (lines 76–100)
- [ ] Remove `_openTemplates()` method (lines 102–149)
- [ ] Remove bookmark button (`save_as_template_button`, lines 305–311)
- [ ] Remove "Templates" button (`templates_button`, lines 341–348)

### Regenerate drift code
- [ ] Run `dart run build_runner build`

### Update test files
- [ ] Edit `test/features/settings/settings_test.dart` — remove `meal_templates` references
- [ ] Edit `test/database_test.dart` — remove template test (lines 124–138)

### Update docs
- [ ] Edit `AGENTS.md` — change "7 tables" to "6 tables"; remove `meal_templates` from list; remove "Meal templates" design rule

### Verify
- [ ] `grep -rn "meal_template" lib/ test/` — no matches
- [ ] `grep -rn "saveAsTemplate\|TemplateFood\|MealTemplatesSheet" lib/ test/` — no matches
- [ ] Run `flutter analyze` — zero issues
- [ ] Run `flutter test` — all pass

---

## Ticket 3 — Fix serving/portion macro math

### Fix `log_food_screen.dart`
- [ ] Change `_selectFood()`: `_servings = 1` instead of `food.servingQuantity` (line 59)
- [ ] Fix `_onSaveAsTemplate()` macro formulas (lines 84–88) — **skip if T2 already removed this method**
- [ ] Fix `_save()` macro formulas (lines 223–226)
- [ ] Fix live preview macro display (lines 388–409)

### Fix `recipe_form_screen.dart`
- [ ] Fix live total macro calculation (lines 284–287)

### Fix `database.dart`
- [ ] Fix `computeRecipeMacros()` (lines 349–352)

### Fix `recipe_ingredient_row.dart`
- [ ] Fix per-row macro display (line 20)

### Add guard
- [ ] Ensure all division sites guard against `servingQuantity == 0` (use `(qty / (food.servingQuantity > 0 ? food.servingQuantity : 1))`)

### Test
- [ ] Write unit tests for per-serving (qty=1) and per-100g (qty=100) normalization
- [ ] Write unit test for `computeRecipeMacros()` normalization
- [ ] Run `flutter analyze` — zero issues
- [ ] Run `flutter test` — all pass

---

## Ticket 5 — Auto-calculate calories from macros in manual food form

### Edit `manual_food_form.dart`
- [ ] Add `_caloriesManuallyEdited = false` field to state
- [ ] Add `onChanged` to protein field that triggers `_autoComputeCalories()`
- [ ] Add `onChanged` to carbs field that triggers `_autoComputeCalories()`
- [ ] Add `onChanged` to fat field that triggers `_autoComputeCalories()`
- [ ] Add `onChanged` to calories field that sets `_caloriesManuallyEdited = true`
- [ ] Implement `_autoComputeCalories()`: parse all three, compute `p*4 + c*4 + f*9`, update calories controller (unless manually edited)

### Test
- [ ] Write widget test: auto-compute from 20p/30c/10f → 290 kcal
- [ ] Write widget test: manual calories override is not overwritten
- [ ] Write widget test: auto-compute resumes after clearing all macros
- [ ] Run `flutter analyze` — zero issues
- [ ] Run `flutter test` — all pass

---

## Final verification

- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — all pass
- [ ] App builds: `flutter build apk --debug` (or equivalent)
