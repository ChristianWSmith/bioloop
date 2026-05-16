# TKT-5: Log food to the viewed date

**Risk**: Medium | **Files**: 5 | **Est**: 2-3hr

---

## Context

The log tab has a date navigator (chevrons + `DayNavigator`) that lets users view entries for past dates, but `_currentDate` only controls the display filter. Both logging paths hardcode `DateTime.now()`:

- `QuickFoodLogSheet._log()` at `quick_food_log_sheet.dart:50`: `final now = DateTime.now().toIso8601String()`
- `RecipeService.logRecipe()` at `recipe_provider.dart:52`: `final now = DateTime.now().toIso8601String()`

This means users can't go back to log a forgotten meal on a previous day, which the issue specifically requests (to improve regression algorithm accuracy).

## Acceptance Criteria

- Logging a food item via the FAB on the log tab stamps it with the currently viewed date (not `DateTime.now()`)
- Navigating to a past date and logging stamps it to that past date
- Navigating to a future date and logging stamps it to that future date
- Logging from the recipe form screen ("Log this recipe") still logs to today (no viewed-date context available)
- All existing tests pass with no modifications (optional params are backward-compatible)
- Button text changes from `"Log to today"` to `"Log entry"`

## Implementation

### 1. `lib/providers/recipe_provider.dart` (`RecipeService.logRecipe()`)

Add optional `loggedAt` param:

```dart
Future<int> logRecipe({
  required int recipeId,
  required double portion,
  required String mealType,
  DateTime? loggedAt,
}) async {
  // ...
  final now = (loggedAt ?? DateTime.now()).toIso8601String();
  // ...
}
```

### 2. `lib/features/logging/widgets/quick_food_log_sheet.dart`

Add optional `loggedAt` param and use it:

```dart
class QuickFoodLogSheet extends ConsumerStatefulWidget {
  final FoodSearchItem food;
  final FoodEntry? sourceEntry;
  final DateTime? loggedAt;  // NEW

  const QuickFoodLogSheet({
    super.key,
    required this.food,
    this.sourceEntry,
    this.loggedAt,  // NEW
  });
  // ...
}
```

In `_log()` (line 50):
```dart
final now = (widget.loggedAt ?? DateTime.now()).toIso8601String();
```

Button text (line 193):
```dart
: const Text('Log entry'),  // was 'Log to today'
```

### 3. `lib/features/recipes/widgets/log_recipe_sheet.dart`

Add optional `loggedAt` param:

```dart
class LogRecipeSheet extends ConsumerStatefulWidget {
  final RecipeDetail detail;
  final DateTime? loggedAt;  // NEW
  // ...
}
```

Pass through in `_log()` (line 35):
```dart
await ref.read(recipeServiceProvider).logRecipe(
  recipeId: widget.detail.recipe.id,
  portion: _portion,
  mealType: _mealType!,
  loggedAt: widget.loggedAt,  // NEW
);
```

Button text (line 124):
```dart
child: const Text('Log entry'),  // was 'Log to today'
```

### 4. `lib/features/recipes/recipe_list_screen.dart`

Add optional `loggedAt` field to the widget class (not just the screen — since `LogRecipeSheet` is created inside `_openRecipe`):

```dart
class RecipeListScreen extends ConsumerWidget {
  final bool pickerMode;
  final DateTime? loggedAt;  // NEW
  // ...
}
```

Pass through in `_openRecipe()` (line 107):
```dart
builder: (_) => LogRecipeSheet(detail: detail, loggedAt: loggedAt),
```

### 5. `lib/features/logging/combined_log_screen.dart`

Thread `_currentDate` through:

```dart
// _showQuickLogSheet (line 87-93):
Future<void> _showQuickLogSheet(FoodSearchItem item) async {
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => QuickFoodLogSheet(
      food: item,
      loggedAt: _currentDate,  // NEW
    ),
  );
}

// _onLogRecipe (line 79-84):
Future<void> _onLogRecipe() async {
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => RecipeListScreen(
        pickerMode: true,
        loggedAt: _currentDate,  // NEW
      ),
    ),
  );
}
```

### 6. `lib/features/recipes/recipe_form_screen.dart`

**No change needed**. Line 268 creates `LogRecipeSheet(detail: detail)` without `loggedAt` — it defaults to `DateTime.now()`, which is correct for logging from the recipe form (no log-tab date context exists).

## Testing

### Unit tests
- **No existing test changes needed** — all new params are optional with backward-compatible defaults
- All existing tests should pass without modification

### Manual verification
1. Open log tab, navigate to yesterday via chevron
2. Tap FAB, search for a food, log it
3. Verify the entry appears under yesterday's entries
4. Navigate back to "Today" — entry should not appear there
5. Repeat with recipe logging (tap recipe book icon → select recipe → log)

### Regression
- Run `flutter analyze` — zero issues
- Run `flutter test` — all existing tests pass
- Verify `QuickFoodLogSheet` and `LogRecipeSheet` still log to today when date-context is unavailable (recipe form path)
