# Discovery — Bioloop Bug Inventory

Bug reports from `issues.txt`, with code-level analysis.

## Table of Contents

1. [Edit entry drawer wording + rounding](#1-edit-entry-drawer-wording--missing-rounding)
2. [Stale dashboard after edit](#2-editing-a-food-entry-produces-stale-dashboard)
3. [Height conversion broken on unit toggle](#3-height-conversion-broken-on-unit-toggle)
4. [Recipe ingredient search lacks recent foods](#4-recipe-ingredient-search-lacks-recent-foods)

---

## 1. Edit entry drawer: wording + missing rounding

**Reported:** "Servings (<quantity> <unit>)" wording is odd; values show long decimals.

**File:** `lib/features/history/widgets/edit_entry_sheet.dart`

### Wording (line 162)

```dart
labelText: 'Servings (${widget.entry.servingLabel})',
```

`servingLabel` is a free-text field (e.g. `"serving"`, `"g"`, `"oz"`). The label reads as e.g. `Servings (g)` which is confusing — it should be `Quantity (g)` or just show the unit.

### Missing rounding (line 36)

```dart
_servingsController = TextEditingController(text: e.servings.toString());
```

`e.servings` is a raw `double` (Drift `RealColumn`). `.toString()` produces full-precision strings like `1.5` or `2.3333333333333335` depending on how the value was computed/stored. The text field shows these unrounded.

**Contrast:** The macro recalculation callback (`_onServingsChanged`, lines 67–70) uses `toStringAsFixed(1)` for calories/protein/carbs/fat — but the servings field itself never gets rounded.

### Save path (line 99)

```dart
servings: double.parse(_servingsController.text),
```

No rounding/normalization on save either — the user's raw input (or the unrounded default) goes straight to the DB.

| Location | Code | Rounded? |
|----------|------|----------|
| Line 36: initial text | `e.servings.toString()` | ❌ |
| Line 99: save | `double.parse(_servingsController.text)` | ❌ |
| Lines 67–70: macro recalc | `toStringAsFixed(1)` | ✅ |

### Scope

1 file, 2 lines to fix:
- Line 36: `e.servings.toStringAsFixed(1)` (or round to 0/1/2 decimals based on unit)
- Line 162: `'Quantity (${widget.entry.servingLabel})'` (or extract just the unit from the label)

---

## 2. Editing a food entry produces stale dashboard

**Reported:** Dashboard still uses pre-edit values after editing a food entry in history.

**Root cause:** The edit save handler (`edit_entry_sheet.dart:_save()`, line 86–130) calls `updateEntry()` then only pops the sheet. It never invalidates any Riverpod provider.

**All other mutation sites** increment `dataTriggerProvider` and/or `ref.invalidate(todaysFoodProvider)`:

| File | Line | Context | Triggers refresh? |
|------|------|---------|-------------------|
| `edit_entry_sheet.dart` | 107–110 | Edit entry save | ❌ — only pops |
| `quick_food_log_sheet.dart` | 92–96 | Quick-log | ✅ |
| `log_food_screen.dart` | 161–162 | Manual log | ✅ |
| `log_food_screen.dart` | 291 | Search result log | ✅ |
| `log_food_screen.dart` | 401 | Barcode log | ✅ |
| `log_recipe_sheet.dart` | 40–41 | Recipe log | ✅ |
| `bodyweight_screen.dart` | 123 | Weight insert | ✅ |
| `bodyweight_screen.dart` | 153 | Weight delete | ✅ |

**Impacted providers:**
- `todaysFoodProvider` (`food_log_provider.dart:27`) — dashboard's today entries stay stale
- `maintenanceProvider` (`maintenance_provider.dart:8`) — watches `dataTriggerProvider`, never re-fires
- `_countDataDaysProvider` (`maintenance_card.dart:12`) — watches `dataTriggerProvider`, never re-fires

**Caller in history screen** (line 112–120) only refreshes the history screen's own paginated list via `_refresh()` — no Riverpod invalidation.

```dart
// history_screen.dart:112–120
Future<void> _editEntry(FoodEntry entry) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EditEntrySheet(entry: entry),
  );
  if (result == true) {
    await _refresh();  // only reloads history's local _entries list
  }
}
```

### Scope

1 file (`edit_entry_sheet.dart`), 2 lines to add after line 107:
```dart
ref.invalidate(todaysFoodProvider);
ref.read(dataTriggerProvider.notifier).state++;
```

---

## 3. Height conversion broken on unit toggle

**Reported:** Starting at 6'4" → 76cm → 2'6" → 30cm on successive imperial/metric toggles.

**Files:** `lib/features/goals/goals_screen.dart` (line 224) and `lib/features/onboarding/onboarding_screen.dart` (line 144)

### Root cause

Both files call the wrong `heightCm()` factory during Imperial→Metric conversion:

```dart
// goals_screen.dart:224 (and onboarding_screen.dart:144)
final heightCm = UnitPreferences.metric().heightCm(feet * 12 + inches);
```

`UnitPreferences.metric()` has `heightFactor: 1.0`, so `heightCm(x)` returns `x / 1.0 = x` — it's the **identity function**. The total inches value passes through unchanged and is displayed as "cm".

**Correct call** should be `UnitPreferences.imperial().heightCm(...)`, which divides by `0.393701` (× 2.54), converting inches back to cm.

### Trace: 6'4" toggled to metric and back

```
Step 1: User enters 6'4" in imperial mode
  → _heightFeetController = "6", _heightInchesController = "4"
  → totalInches = 6*12 + 4 = 76

Step 2: User toggles to metric (line 220–228 fires)
  → UnitPreferences.metric().heightCm(76) = 76 / 1.0 = 76.0
  → _heightController.text = "76.0"     ← BUG: should be 193.0

Step 3: User toggles back to imperial (line 204–213 fires)
  → reads _heightController.text = "76"
  → UnitPreferences.imperial().displayHeight(76) = 76 * 0.393701 = 29.92"
  → feet = 29.92 ~/ 12 = 2, inches = (29.92 % 12).round() = 6
  → shows "2'6""                              ← COMPOUNDED BUG
```

Matches bug report exactly.

### Why the other height conversions work

| Location | Pattern | Correct? |
|----------|---------|----------|
| `_loadGoals` DB → fields | uses live `_unitPrefs.displayHeight()` | ✅ |
| `_save` fields → DB | uses live `_unitPrefs.heightCm()` | ✅ |
| `_fatGramPreview` | uses live `_unitPrefs.heightCm()` | ✅ |
| `_onUnitsChanged` metric→imperial | `UnitPreferences.imperial().displayHeight()` | ✅ |
| **`_onUnitsChanged` imperial→metric** | **`UnitPreferences.metric().heightCm()`** | **❌ BUG** |

All other conversion sites use the **live** `_unitPrefs` getter (which reflects current `_useImperial`). The bug is only in the `_onUnitsChanged` handler where a hardcoded factory is used instead of the imperial one.

### Test gap

Existing test `'units toggle switches height fields'` (goals_screen_test.dart, lines 132–152) only checks that the **number of height fields** changes (3↔4), never that the **value** survives the round-trip.

### Scope

2 files, 1 line each:
- `lib/features/goals/goals_screen.dart` line 224
- `lib/features/onboarding/onboarding_screen.dart` line 144

Fix: `UnitPreferences.imperial().heightCm(...)` instead of `UnitPreferences.metric().heightCm(...)`.

---

## 4. Recipe ingredient search lacks recent foods

**Reported:** When creating a recipe and searching for ingredients, recently logged foods aren't shown, unlike the normal food search screen.

**File:** `lib/features/recipes/recipe_form_screen.dart` (line 70–79)

### Code parity analysis

`RecipeFormScreen._addIngredient()` and `LogFoodScreen._onSearch()` both instantiate `FoodSearchDelegate` identically for recent-foods:

| | `LogFoodScreen._onSearch()` | `RecipeFormScreen._addIngredient()` |
|---|---|---|
| `showSearch` wrapper | `_onSearch()` | `_addIngredient()` |
| `query` initial | `""` (empty) | `""` (empty) |
| `onQuickLog` | provided | omitted |
| `onCreateCustomFood` | provided | provided |
| `_RecentFoodsSection` renders when `query.isEmpty`? | ✅ yes (line 51) | ✅ yes (same code path) |

The only code difference is `onQuickLog`, which only controls the trailing "+" icon button on each recent food item — it does **not** affect whether `_RecentFoodsSection` is rendered.

### How `_RecentFoodsSection` visibility works

In `food_search_delegate.dart:_buildContent()`:

```dart
if (query.isEmpty)
  _RecentFoodsSection(         // ALWAYS rendered when query is empty
    onSelectItem: (item) => close(context, item),
    onQuickLog: onQuickLog != null ? ... : null,  // just controls "+" button
  ),
```

The section is rendered unconditionally when `query.isEmpty`, regardless of `onQuickLog`. Both `LogFoodScreen` and `RecipeFormScreen` start with `query.isEmpty`, so both should show the section.

### Most likely explanations

1. **Silent error in `recentFoodsProvider`:** If the provider errors inside the `showSearch` overlay context, `_RecentFoodsSection` hits the `.error` branch which renders a small "Could not load recent foods" text — easily overlooked by the user.

2. **Empty data state:** If the recipe picker is used on a fresh install or after data reset, `getRecentFoods()` returns empty list → `_RecentFoodsSection` renders `SizedBox.shrink()` (no visible output).

3. **Riverpod context resolution:** `showSearch` pushes a route via `Navigator.of(context)`. In rare cases with nested Navigators (e.g. `_AppShell` vs. pushed route), the context chain might not reach the `ProviderScope`. However, `RecipeFormScreen` is itself a `ConsumerStatefulWidget` with working `ref`, so its `context` is definitely within a `ProviderScope`.

4. **User perception:** The user may be typing a query before noticing recent foods, making `query` non-empty and hiding the section.

### ⚠️ Needs reproduction to confirm

The code analysis suggests recent foods **should** appear. To determine the actual cause:
- Reproduce on device: navigate to recipe form → tap "Add ingredient" → observe whether recent foods render below the search bar before typing
- If they don't appear: check for errors in the Riverpod devtools or wrap `_RecentFoodsSection` in a try-catch to capture the error
- If they do appear: the only remaining parity gap is the missing quick-log "+" button (adding `onQuickLog` delegates to the recipe flow needs UX discussion — recipe context needs quantity dialog, not instant log)

### Scope

Unknown until reproduced. Minimum: add `onQuickLog` support to recipe ingredient picker for parity of the "+" button. Maximum: debug Riverpod context resolution if the section truly doesn't render.

---

### Bug summary table

| # | Bug | Files affected | Lines to change | Certainty | Has test coverage? |
|---|-----|---------------|----------------|-----------|-------------------|
| 1 | Edit entry wording + rounding | 1 | 2 | Confirmed | No |
| 2 | Stale dashboard after edit | 1 | 2 | Confirmed | No |
| 3 | Height conversion broken | 2 | 2 | Confirmed | Partial (checks field count only) |
| 4 | Recipe search missing recent foods | 1 (+ debug) | TBD | Needs repro | No |
