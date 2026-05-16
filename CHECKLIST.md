# Implementation Checklist

## Execution order (ascending complexity/risk)

| # | Ticket | Description | Est. | Status | Owner | Notes |
|---|--------|-------------|------|--------|-------|-------|
| 1 | [TKT-1](tickets/TKT-1-recipe-delete-cascade.md) | Fix recipe delete cascade | <15min | ✅ Done | | `recipe_list_screen.dart` |
| 2 | [TKT-2](tickets/TKT-2-bodyweight-delete-timestamp.md) | Format bodyweight delete timestamp | <15min | ✅ Done | | `bodyweight_screen.dart` |
| 3 | [TKT-3](tickets/TKT-3-longpress-food-delete.md) | Long press to delete food entries | <15min | ✅ Done | | `combined_log_screen.dart` |
| 4 | [TKT-4](tickets/TKT-4-web-search-retries.md) | Web search retries + error differentiation | 2-3hr | ✅ Done | | Client + service + delegate |
| 5 | [TKT-5](tickets/TKT-5-log-to-viewed-date.md) | Log food to viewed date | 2-3hr | ⬜ Pending | | 5 files, threading date through |
| 6 | [TKT-6](tickets/TKT-6-remove-bodyweight-goal.md) | Remove bodyweight goal feature | 4-6hr | ⬜ Pending | | Schema migration + 3 screens + tests |

## Per-ticket checkboxes

### TKT-1: Fix recipe delete cascade
- [x] Add `deleteIngredientsForRecipe()` call before `deleteRecipe()` in `_deleteRecipe()`
- [x] Run `flutter analyze` — zero issues
- [x] Run `flutter test` — all pass (recipe-specific: 22/22). Pre-existing failure in `search_delegate_test.dart` unrelated.

### TKT-2: Format bodyweight delete timestamp
- [x] Replace raw `entry.loggedAt` with formatted date in `_confirmDelete()` dialog
- [x] Run `flutter analyze` — zero issues
- [x] Run `flutter test` — all pass

### TKT-3: Long press to delete food entries
- [x] Add `onLongPress: () => _deleteEntry(entry)` to `ListTile` inside `Dismissible`
- [x] Run `flutter analyze` — zero issues
- [x] Run `flutter test` — all pass

### TKT-4: Web search retries + error differentiation
- [x] Add retry loop to `OpenFoodFactsClient.search()` (max 3 attempts, exponential backoff)
- [x] Catch `TimeoutException` in client error handlers
- [x] Add `WebSearchResult` sealed class to `food_search_provider.dart`
- [x] Update `FoodSearchService.searchWeb()` to return `WebSearchResult`
- [x] Update `_WebSearchContent` to show differentiated messages + tap-to-retry
- [x] Update tests in `test/api/open_food_facts_client_test.dart`
- [x] Run `flutter analyze` — zero issues
- [x] Run `flutter test` — all pass
- [ ] Manual: verify "No results found" vs "Search failed" in app (requires API access)

### TKT-5: Log food to viewed date
- [ ] Add optional `loggedAt` to `QuickFoodLogSheet` + use in `_log()`
- [ ] Add optional `loggedAt` to `LogRecipeSheet` + pass to `logRecipe()`
- [ ] Add optional `loggedAt` to `RecipeService.logRecipe()` + use in insert
- [ ] Add optional `loggedAt` field to `RecipeListScreen` + pass to `LogRecipeSheet`
- [ ] Update `CombinedLogScreen._showQuickLogSheet()` to pass `_currentDate`
- [ ] Update `CombinedLogScreen._onLogRecipe()` to pass `_currentDate`
- [ ] Change button text: `"Log to today"` → `"Log entry"` (both sheets)
- [ ] Run `flutter analyze` — zero issues
- [ ] Run `flutter test` — all pass
- [ ] Manual: log food while viewing a past date, verify it appears there

### TKT-6: Remove bodyweight goal feature
- [ ] **6a Schema**: Remove `goalWeightKg` from `user_goals.dart`
- [ ] **6a Migration**: Bump schema v4→v5, add `deleteColumn` to migration
- [ ] **6a Codegen**: Run `dart run build_runner build`
- [ ] **6b Onboarding**: Remove controller, conversion logic, save logic, UI section
- [ ] **6c Goals**: Remove controller, load/save logic, conversion logic, UI field
- [ ] **6d Dashboard**: Remove conditional render + `_buildGoalWeightCard()` method
- [ ] **6e Tests**: Update `test/database_test.dart`
- [ ] **6e Tests**: Update `test/widget_test.dart`
- [ ] **6e Tests**: Update `test/features/goals/goals_screen_test.dart`
- [ ] **6e Tests**: Update `test/features/dashboard/dashboard_screen_test.dart`
- [ ] **6e Tests**: Update `test/providers/macro_targets_provider_test.dart`
- [ ] Run `flutter analyze` — zero issues
- [ ] Run `flutter test` — all pass
- [ ] Manual: verify onboarding, goals, dashboard no longer show goal weight

## Global regression gates

Each ticket must pass these before marking complete:

| Gate | Command |
|------|---------|
| Analyze | `flutter analyze > analyze.log 2>&1 && cat analyze.log` |
| Tests | `flutter test > test.log 2>&1 && cat test.log` |
| Drift codegen (TKT-6 only) | `dart run build_runner build` |
