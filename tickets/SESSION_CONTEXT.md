## Goal
- Continue implementing Phase 3 bug fix tickets (#009, #010, #011) in list order.

## Constraints & Preferences
- "Disable, don't validate" — save button simply doesn't respond when disabled.
- Calorie adjustment warning uses `colorScheme.tertiary`, not `error` (informational, non-blocking).
- All DB values stored in metric (cm, kg) regardless of display unit.
- Unit toggle must appear before (above) height fields so it controls them naturally.
- Debounce implemented at the UI delegate layer (`_DebouncedSearch` StatefulWidget), not the service layer.

## Progress
### Done
- **Ticket #001 — #006**: Phase 2 onboarding improvements.
- **Ticket #007 — Stale dashboard after reset**: Added `resetTriggerProvider` watches to 4 leaf providers.
- **Ticket #008 — Recipes screen "+" button**: Added always-visible `FloatingActionButton` with `Icons.add` to `RecipeListScreen`.
- **Ticket #009 — Templates empty state add button**: Enhanced `MealTemplatesSheet` empty state with `bookmark_border` icon, explanatory text, and `FilledButton.tonalIcon("Log a food")` that pops the sheet back to the log screen.
- **Ticket #010 — Food search debouncing**: Added `_DebouncedSearch` StatefulWidget inside `FoodSearchDelegate._buildContent()` that debounces `searchService.search()` calls by 400ms. Uses `ValueKey(_debouncedQuery)` so the `FutureBuilder` only restarts after the debounce fires, eliminating visual jitter from spinner resets on each keystroke.
- **Ticket #014 — Onboarding vs goals parity audit**: Section headers renamed, unit toggle before height, real-time fat grams preview, carbs section, inches default-0.

### In Progress
- (none)

### Blocked
- (none)

## Key Decisions
- `resetTriggerProvider` watches added to leaf providers only; `macroTargetsProvider` auto-refreshes via its upstream dependencies.
- Inches field in both screens defaults to 0 if empty (defensive `double.tryParse ?? 0`).
- FAB chosen over removing AppBar guard for recipes because FAB is more consistent with Material 3 patterns.
- Templates empty-state button pops the sheet (returns to log screen) rather than creating templates inline, because templates require food entries from the log screen.
- Debounce uses `_DebouncedSearch` StatefulWidget (preferred option in ticket) over service-level debouncing, keeping the UI timing concern at the delegate layer. `onSelectItem` callback avoids coupling to `SearchDelegate` internals.
- Serving stepper `+` button got `Key('increment_servings')` to disambiguate from the search delegate's "Create custom food" icon in tests.

## Next Steps
1. **#011 — CSV export direct save** (next unlocked in Phase 3).
2. After each ticket: `flutter analyze && flutter test`.

## Critical Context
- `flutter analyze` passes (only pre-existing `use_build_context_synchronously` info in `log_food_screen.dart`).
- Full test suite: **242 pass, 2 fail, 3 skip** — only pre-existing failures are history screen "Today" date-format tests.
- Provider dependency chain for dashboard: `todaysFoodProvider`, `bodyweightProvider`, `userGoalsProvider`, `maintenanceProvider` each `ref.watch(resetTriggerProvider)`; `macroTargetsProvider` depends on upstreams.
- Debounce timer: 400ms, managed via `Timer` in `_DebouncedSearchState`. Cancelled on `dispose()` (route close or widget removal).
- `find.text('165')` from log screen's macro display can match even when the search delegate is open (overlay entries are in the widget tree but not offstage), so tests use `skipOffstage`-aware checks or keyed finders to disambiguate.

## Relevant Files
- `lib/features/logging/widgets/meal_templates.dart`: Empty state enhanced with icon, text, "Log a food" button (`Key('empty_state_log_food')`).
- `lib/features/logging/widgets/food_search_delegate.dart`: Added `_DebouncedSearch` StatefulWidget with 400ms debounce timer; `onSelectItem` callback.
- `lib/features/logging/widgets/serving_size_picker.dart`: Added `Key('increment_servings')` to `+` `IconButton`.
- `test/features/logging/log_food_screen_test.dart`: `searchAndTapResult` waits 600ms for debounce; 2 new debounce tests added.
- `test/features/logging/meal_templates_test.dart`: Updated `searchAndTapResult` delays; added empty state button tests.
- `tickets/CHECKLIST.md`: #001–#010, #014 checked off.
