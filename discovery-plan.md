# bioloop — Action Items: Discovery & Implementation Plan

## Per Action Item — Root Cause Analysis

| # | Issue | Root Cause | Key Files |
|---|-------|------------|-----------|
| 1 | **App icon not applying** | `flutter_launcher_icons` package is configured in `pubspec.yaml` (lines 24–28) but **not listed in `dev_dependencies`**. The 5 mipmap `ic_launcher.png` files are default Flutter placeholders (442–1443 bytes), not generated from the custom 278 KB source at `assets/icon/app_icon.png`. No adaptive icon dir (`mipmap-anydpi-v26/`) exists. | `pubspec.yaml` |
| 2 | **Onboarding: height as cm OR ft+in** | Onboarding hardcodes `suffixText: 'cm'` regardless of `_useImperial` toggle. The goals screen already has a working implementation via `_buildHeightField()` — metric shows one `TextFormField` with `cm` suffix; imperial shows a `Row` of two fields (ft + in) — and `_onUnitsChanged()` which converts bidirectionally. | `onboarding_screen.dart`, `goals_screen.dart` |
| 3 | **Onboarding: birthdate instead of age** | `UserGoals` table stores a plain `IntColumn get age`. Onboarding has a `TextFormField` for age. Mifflin-St Jeor receives `age` directly. No birthdate column or computed-age logic exists. | `onboarding_screen.dart`, `tables/user_goals.dart`, `mifflin_st_jeor.dart` (and all callers) |
| 4 | **Onboarding: weight in kg/lbs + toggle timing** | Weight field hardcoded to `kg` suffix. The imperial toggle appears *after* the weight field in the form layout, so it can't influence it. Goals screen handles this correctly with toggle-positioned-first layout and conversion. | `onboarding_screen.dart` |
| 5 | **Onboarding: toggle does nothing** | The toggle (`_useImperial`) is only stored to DB — it never controls field display or conversion in onboarding. Height/weight always show metric. Confirmed cosmetic-only. | `onboarding_screen.dart` |
| 6 | **Onboarding: don't prompt for date** | Date picker + `_dateController` + `showDatePicker` call on the onboarding form, allowing user to pick any date from 2000 to today. | `onboarding_screen.dart` |
| 7 | **Highlight slider recommended ranges** | Both sliders (`proteinGPerLb` 0.5–2.0, `fatCaloriePct` 10–50%) have no visual indicators for "recommended" ranges — no colored track, no overlay markers, no helper text. | `onboarding_screen.dart`, `goals_screen.dart` |
| 8 | **Reset data: dashboard stale** | Dashboard watches four `FutureProvider`s (`todaysFoodProvider`, `macroTargetsProvider`, `bodyweightProvider`, `userGoalsProvider`). These providers cache their results and **none of them watch `resetTriggerProvider`**. After `db.resetAll()` clears all tables and increments the trigger, the providers still return their old cached values. The dashboard checks `entries.isEmpty && weights.isEmpty && goals == null` only *after* all providers resolve — but they resolve from cache. Logging a new entry forces invalidation of `todaysFoodProvider`, which triggers a cascade refresh. | `dashboard_screen.dart`, `reset_provider.dart`, all four dashboard providers, `database.dart` |
| 9 | **Recipes: typo + no "+" button** | `RecipeListScreen` is only instantiated from `LogFoodScreen` with `pickerMode: true`. The AppBar add button (`Icons.add`) is **conditionally hidden** by `if (!pickerMode)`. There is **no FAB**. Empty state reads "No recipes yet.\nTap + to create one." but no + is visible. The non-picker mode (where + appears) is only used in tests. | `recipe_list_screen.dart`, `log_food_screen.dart` |
| 10 | **Templates: no way to add** | Templates can only be created from the Log screen *after* selecting a food (bookmark icon button appears next to search field). `MealTemplatesSheet` has no "create template" button in its empty state. | `meal_templates.dart`, `log_food_screen.dart` |
| 11 | **"white rice" no results** | Likely a query-param or data-availability limitation of the OpenFoodFacts API. Uses `search_terms` param on `/cgi/search.pl`. Needs direct API testing to confirm. | `open_food_facts_client.dart` |
| 12 | **Search fires on every keypress** | `FoodSearchDelegate._buildContent()` uses `FutureBuilder` keyed with `ValueKey(query)`. Every keystroke changes the key → abandons old Future → creates new one → calls `searchService.search(query)` which hits local DB + possibly OpenFoodFacts API. No debounce timer. | `food_search_delegate.dart`, `food_search_provider.dart` |
| 13 | **Goals toggle works, onboarding doesn't** | Same root cause as #2/#4/#5 — onboarding toggle is cosmetic-only. Goals screen has bidirectional unit conversion. | (same as #2/#5) |
| 14 | **Calorie adjustment warnings** | Neither onboarding nor goals screen has any warning when user enters deficit > 500 or surplus > 300. The `_ratePreview()` helper just shows lb/week gain/loss without flagging concern. | `onboarding_screen.dart`, `goals_screen.dart` |
| 15 | **Parity: onboarding vs goals** | Multiple gaps: unit toggle behavior (items 2,4,5), birthdate vs age (item 3), save button disable (item 17), slider recommendations (item 7), calorie warnings (item 14). Goals screen is the reference implementation. | All onboarding + goals files |
| 16 | **CSV export: save to device vs share** | Uses `Share.shareXFiles()` which opens the OS share sheet. On Android, this surfaces social apps, messaging, email — not a "Save to Files" / "Save to Downloads" option. `share_plus` v10 handles the FileProvider internally. | `export.dart`, `history_screen.dart`, `bodyweight_screen.dart` |
| 17 | **Onboarding save button always active** | `ElevatedButton` has no `onPressed` guard. Goals screen uses `_canSave` getter checking all fields + changes. | `onboarding_screen.dart` |

---

## Implementation Plan

Ordered by dependency (Phase 1 must come first; Phases 2–4 are independent of each other within each phase).

### Phase 1 — Database Schema Changes

| Order | Item | Description | Impact |
|-------|------|-------------|--------|
| 1.1 | #3 | Add `birthdate` column (`TextColumn`, ISO date string) to `UserGoals`. Keep `age` column for now (backward compat during migration). Update `upsertGoals()` to accept birthdate. Update Mifflin-St Jeor callers to compute age from birthdate on the fly. | `user_goals.dart`, `database.dart`, `onboarding_screen.dart`, `goals_screen.dart`, `mifflin_st_jeor.dart` |
| 1.2 | #4/#5/#13 | Port the working unit-toggle pattern from goals screen to onboarding: move toggle before fields, make height/weight fields respond to `_useImperial`, add bidirectional conversion in `_onUnitsChanged()`. | `onboarding_screen.dart` |

### Phase 2 — Onboarding Improvements

| Order | Item | Description |
|-------|------|-------------|
| 2.1 | #6 | Remove date field + date picker. Set `loggedAt: DateTime.now().toIso8601String()` when inserting initial weight. |
| 2.2 | #17 | Add `_canSave` getter checking: sex selected, all required fields filled (`_heightController`, `_weightController`, etc.). Bind to `ElevatedButton.onPressed`. |
| 2.3 | #7 | Add visual recommended-range indicators on protein and fat sliders (both onboarding and goals): e.g., colored track overlay, tick marks, or helper text showing "Recommended: 0.8–1.2 g/lb" / "Recommended: 20–35%". |
| 2.4 | #14 | Add warning dialog when user enters deficit > 500 or surplus > 300 (both screens). Still allow the value — "Disable, don't validate" means show warning, not block. |
| 2.5 | #15 | Audit remaining parity gaps: check that both screens handle fields identically (layout, labels, behavior). |

### Phase 3 — Bug Fixes

| Order | Item | Description |
|-------|------|-------------|
| 3.1 | #8 | Fix stale dashboard after reset. Option A: add `ref.watch(resetTriggerProvider)` to each dashboard provider. Option B: add explicit `ref.invalidate(...)` calls after `resetAll()` in settings. Option A is more robust. |
| 3.2 | #9 | Add a FAB to `RecipeListScreen` (always visible, regardless of picker mode) with `Icons.add`. Fix empty state text to describe actual usage. |
| 3.3 | #10 | Add "Create template" button/option to empty state of `MealTemplatesSheet`. |
| 3.4 | #12 | Add debounce timer (300–500ms) in `FoodSearchDelegate._buildContent()` before calling `searchService.search()`. Cancel previous timer on each keystroke. |
| 3.5 | #16 | Try alternative: write CSV to `getApplicationDocumentsDirectory()` or `getDownloadsDirectory()` and use `OpenFileX` / `open_file` plugin, or use `Share.shareXFiles` with MIME type `text/csv` to hint file-save targets. |

### Phase 4 — Polish

| Order | Item | Description |
|-------|------|-------------|
| 4.1 | #1 | Add `flutter_launcher_icons: ^0.14.3` to `dev_dependencies`, run `dart run flutter_launcher_icons` to regenerate all mipmap densities + adaptive icon. |
| 4.2 | #11 | Test OpenFoodFacts API directly with different query formats (`search_terms=white+rice`, `search_terms=white%20rice`, different page sizes). If the API genuinely lacks the data, note as known limitation. |

---

## Test Strategy

- **Phase 1**: Update `user_goals_test.dart` (if exists) or add tests for birthdate computation. Verify existing tests still pass.
- **Phase 2**: Widget tests for onboarding screen — verify `_canSave` states, toggle behavior, slider indicators.
- **Phase 3**: Widget test for dashboard after reset (mock providers, increment trigger, verify providers re-resolve). Test search debounce with fake async. Test export MIME type.
- **Phase 4**: Run `flutter analyze` to ensure zero errors. Run `flutter test` for full suite.

Command to run at each phase: `flutter analyze && flutter test`
