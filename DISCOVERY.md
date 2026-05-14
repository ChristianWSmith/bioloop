# Discovery — Bioloop Feature Requests

## Table of Contents

1. [Redundant "grams per serving" field](#1-redundant-grams-per-serving-field)
2. [OpenFoodFacts serving size parsing](#2-openfoodfacts-serving-size-parsing)
3. [Unit system consistency — imperial/metric everywhere](#3-unit-system-consistency--imperialmetric-everywhere)
4. [Stale maintenance estimate on dashboard](#4-stale-maintenance-estimate-on-dashboard)
5. [Tap recent entry to re-log](#5-tap-recent-entry-to-re-log)

---

## 1. Redundant "grams per serving" field

### Files & usage inventory

| File | Lines | Role |
|------|-------|------|
| `lib/core/database/tables/foods.dart` | 8 | Column definition: `RealColumn get servingSizeGrams => real().nullable()();` |
| `lib/features/logging/widgets/manual_food_form.dart` | 29, 43, 131–133, 150–152, 340–354 | Controller (declared/disposed), written to DB and returned `Food` object, `TextFormField` widget labeled `"Grams per serving (optional)"` |
| `lib/features/logging/log_food_screen.dart` | 132, 283 | Written to DB when caching API food; passed to `ServingSizePicker` |
| `lib/features/logging/widgets/serving_size_picker.dart` | 11, 19 | Declares `final double? servingSizeGrams` field — **never read or rendered in `build()`** |
| `lib/providers/food_search_provider.dart` | 16, 30, 45, 59, 104 | Property, constructor, `fromFood()`, `fromFoodResult()`, `saveApiResult()` DB write |
| `lib/core/api/models/food_result.dart` | 4, 17, 43, 53, 64, 76 | Property, constructor, `fromJson()` parses from API's `gramEquivalent`, fallback sets to `100` |
| `lib/core/database/database.dart` | 51, 55 | Migration SQL reads `serving_size_grams` to backfill `serving_unit` / `serving_quantity` |
| `lib/features/recipes/recipe_form_screen.dart` | 119 | Pass-through when constructing `Food` from search results |

### Test files with `servingSizeGrams`

| File | Lines |
|------|-------|
| `test/features/logging/manual_food_form_test.dart` | 136, 152 |
| `test/features/logging/log_food_screen_test.dart` | 21, 32 |
| `test/features/recipes/recipes_test.dart` | 18, 28, 38, 278, 357, 369 |
| `test/providers/food_search_provider_test.dart` | 99 |
| `test/api/open_food_facts_client_test.dart` | 51, 64, 80, 104 |

### Key insight

`servingSizeGrams` is **never used in any calculation or display**. All macro scaling uses only `servingQuantity`:

```
macro * (qty / servingQuantity)
```

The field is purely informational/historical — a vestige of schema v1 before `servingQuantity` + `servingUnit` were split out. The only place it appears in the UI is the manual food form field labeled "Grams per serving (optional)", which is redundant when the serving unit is already "g" and confusing otherwise.

### Removal assessment

Two options:
- **Full removal** — drop column from schema (migration v2→v3), remove from all files (8 files, ~30 lines of production code, ~10 lines of test code). Low risk since no calculation or display depends on it.
- **Hide only** — just remove the `TextFormField` from `ManualFoodForm` and always store `null` for new foods. Avoids a schema migration but leaves dead column in DB.

The `FoodResult.fromJson()` parser currently uses `gramEquivalent` for `servingSizeGrams` — this logic can be simplified to just drop that field from the output record since it's never consumed.

---

## 2. OpenFoodFacts serving size parsing

### Current ingestion pipeline

```
OpenFoodFacts API (JSON)
  ↓ HTTP
open_food_facts_client.dart (search / getByBarcode)
  ↓ raw JSON
FoodResult.fromJson(json)              ← CRITICAL FILE: food_result.dart
  ├─ reads serving_size (raw string, e.g. "1 cup (45g)")
  ├─ reads nutriments._serving and _100g values
  ├─ calls _parseServingInfo(rawServingSize)   ← THE ONLY EXISTING PARSER
  └─ constructs FoodResult with servings columns
  ↓
FoodSearchItem.fromFoodResult()         ← pass-through in food_search_provider.dart
  ↓
FoodsCompanion.insert(...)             ← DB write in log_food_screen.dart or food_search_provider.dart
```

### Current parser (`_parseServingInfo` in `food_result.dart:95–119`)

```dart
static ({double quantity, String unit, double? gramEquivalent})?
    _parseServingInfo(String label) {
  // Regex 1: "1 bar (40g)" — quantity + unit + parenthetical grams
  final fullMatch = RegExp(...).firstMatch(label);
  // Regex 2: "100g" — pure grams
  final simpleGrams = RegExp(...).firstMatch(label);
  return null;  // for unparseable strings
}
```

### What it handles correctly

| Example | quantity | unit | gramEquivalent |
|---------|----------|------|----------------|
| `"100g"` | 100 | g | 100 |
| `"1 bar (40g)"` | 1 | bar | 40 |
| `"1/2 cup (120g)"` | 0.5 | cup | 120 |
| `"1 cup"` | 1 | cup | null |
| `"0.25 cup (45g)"` | 0.25 | cup | 45 |
| `"1 packet (2g)"` | 1 | packet | 2 |
| `"2 slices"` | 2 | slices | null |
| `"14 crackers (30 g)"` | 14 | crackers | 30 |
| `"1 portion (15g)"` | 1 | portion | 15 |

### What it fails on

| Example | Problem |
|---------|---------|
| `"100 grams"` | simpleGrams regex expects `g$` not `grams$`; fullMatch captures unit=`grams` (not normalized to `g`) |
| `"100.0g"` | decimal in simpleGrams regex: `(\d+(?:\.\d+)?)\s*g$` — actually works fine |
| `"1 cup (8oz)"` | gramEquivalent = 8 when it should convert oz→grams (~227g) |
| `"1 portion (15 ml)"` | gramEquivalent = 15 when it should be volume, not weight |
| `"15 ml"` | Matches neither regex → returns null → defaults to `servingQuantity=1, servingUnit='serving'` |
| `"8 fl oz (240g)"` | fullMatch captures `fl` as unit, losing `oz` word |
| `"4.7 g (1 SLICE)"` | The gram value `4.7` is before the unit in the text — the regex expects `(N g)` at the end; this is a non-standard format |
| `"about 1 cup (240g)"` | Leading text before quantity — `^` anchor in regex fails |

### Where to insert a new parser

The single insertion point is `FoodResult.fromJson()` in `lib/core/api/models/food_result.dart:95–119`. Replace `_parseServingInfo()` with a more robust parser that:

1. **Extracts gram weight from parenthetical expressions** (already works for most cases)
2. **Normalizes units** — `g` → `g`, `grams` → `g`, `gram` → `g`
3. **Converts non-gram units to grams** where possible — `oz` → `g × 28.35`, `cup` → `g` (using density table or approximate conversions)
4. **Prefers grams as the default unit** — if a gram equivalent is found, use `servingQuantity = grams, servingUnit = 'g'` rather than the original unit
5. **Falls back to any numeric value** if grams can't be determined — extract the numeric portion and use original unit
6. **Never returns null** — always returns a best-effort parsed result

### Test coverage gap

No dedicated unit tests for `_parseServingInfo()`. Only 3 test cases in `test/api/open_food_facts_client_test.dart` exercise it indirectly through `FoodResult.fromJson()`.

---

## 3. Unit system consistency — imperial/metric everywhere

### What `UnitPreferences` currently exposes

**File:** `lib/providers/unit_preferences_provider.dart`

| Member | Purpose |
|--------|---------|
| `useImperial` | Whether the user prefers imperial |
| `weightFactor` | 1.0 (metric) or 2.20462 (imperial) |
| `weightUnit` | `'kg'` or `'lb'` |
| `heightFactor` | 1.0 (metric) or 0.393701 (imperial) |
| `heightUnit` | `'cm'` or `'ft/in'` |
| `displayWeight(double kg)` | kg → display value |
| `kgWeight(double display)` | display → kg |

**Missing helpers:**
- `displayHeight(double cm)` / `heightCm(double display)` — height converted inline with raw factors everywhere
- `displayRate(double kgPerWeek)` / `rateUnit` — weight change rate always hardcoded `lb/week`
- `proteinDisplayFactor` / `proteinUnit` — protein slider always shows `g/lb`

### All hardcoded unit violations

#### Protein slider — `g/lb` regardless of preference

| File | Lines | What |
|------|-------|------|
| `lib/features/goals/goals_screen.dart` | 32, 503, 511, 515 | Variable `_proteinGPerLb`, labels `g/lb` |
| `lib/features/onboarding/onboarding_screen.dart` | 33, 522, 530, 534 | Same pattern |
| `lib/providers/macro_targets_provider.dart` | 59–61 | Always converts weight to lb × g/lb |

For metric users, `g/lb` should become `g/kg` (multiply displayed value by 2.20462; range 0.5–2.0 g/lb ≈ 1.1–4.4 g/kg).

#### Weight change rate — `lb/week` regardless of preference

| File | Lines | What |
|------|-------|------|
| `lib/features/dashboard/dashboard_screen.dart` | 298, 305, 313 | Rate calc, threshold `0.3` (imperial value), display `'lb/week'` |
| `lib/features/goals/goals_screen.dart` | 122–123 | Rate preview `'lb/week'` |
| `lib/features/onboarding/onboarding_screen.dart` | 66–67 | Rate preview `'lb/week'` |
| `lib/providers/macro_targets_provider.dart` | 15, 33 | Field `rateLbsPerWeek`, calc `rate = adjustment * 7 / 3500` |

#### Height conversion — inline raw factors, not via `UnitPreferences`

| File | Lines | What |
|------|-------|------|
| `lib/features/goals/goals_screen.dart` | 69–73, 200–206, 242–245 | Inline `2.54`, `30.48` factors |
| `lib/features/onboarding/onboarding_screen.dart` | 119–123, 139–141, 176–179, 245–248 | Same |

#### CSV export — always `kg`

| File | Line | What |
|------|------|------|
| `lib/features/history/export.dart` | 30–33 | Header `weight_kg,unit`, always writes `,kg` |

### What already works correctly

- **Weight display** — bodyweight screen, sparkline, goal weight card: all use `unitPreferencesProvider.displayWeight()`
- **Macro values** — always in g/kcal (per design rules, no conversion needed)

### What new helpers `UnitPreferences` needs

```dart
double displayHeight(double cm) => cm * heightFactor;
double heightCm(double display) => display / heightFactor;
double get rateFactor => useImperial ? 2.20462 : 1.0;
String get rateUnit => useImperial ? 'lb/week' : 'kg/week';
double get proteinDisplayFactor => useImperial ? 1.0 : 2.20462;
String get proteinUnit => useImperial ? 'g/lb' : 'g/kg';
double displayProteinGPerLb(double gPerLb) => gPerLb * proteinDisplayFactor;
double proteinGPerLbFromDisplay(double display) => display / proteinDisplayFactor;
```

### DB column name

`user_goals.proteinGPerLb` stores values in g/lb internally. The UI converts at read/write time for metric users. The column name is misleading but acceptable as an internal detail — changing it would require a schema migration.

---

## 4. Stale maintenance estimate on dashboard

### Provider dependency graph

```
User logs bodyweight
  → bodyweight_screen.dart:121 ref.invalidate(bodyweightProvider)
  → bodyweightProvider recomputes
  → macroTargetsProvider watches bodyweightProvider → recomputes
  → maintenanceProvider does NOT watch bodyweightProvider → STALE ❌

User logs food
  → log_food_screen.dart:161 ref.invalidate(todaysFoodProvider)
  → todaysFoodProvider recomputes  → (watched by DashboardScreen rings)
  → maintenanceProvider does NOT watch todaysFoodProvider → STALE ❌
```

### What `maintenanceProvider` watches

**File:** `lib/providers/maintenance_provider.dart:7–22`

```dart
final maintenanceProvider = FutureProvider<MaintenanceResult?>((ref) async {
  ref.watch(resetTriggerProvider);    // ONLY trigger — incremented on FULL RESET only
  final db = ref.watch(databaseProvider);  // constant after init
  final allFoodEntries = await db.getEntriesPaginated(limit: 365);
  final allWeights = await db.getWeights();
  return MaintenanceCalculator.calculate(...);
});
```

`resetTriggerProvider` is incremented **only** in `settings_screen.dart:56` during full data reset. No `ref.invalidate(maintenanceProvider)` exists anywhere in the codebase.

### What "0/14" means

The `_countDataDaysProvider` (in `maintenance_card.dart:11–32`) computes overlapping days with both food and weight entries in the last 30 days. It uses `ref.read(databaseProvider)` — **not reactive**, computes once on first access.

`MaintenanceCalculator.calculate()` requires at least 14 paired data points (each = 3+ weights in ±3-day window + 3+ days of calorie data in same window). Also requires 7+ recent weight entries overall.

So `0/14` = zero overlapping days with sufficient data, and/or insufficient weight entries.

### Two independent breaks in the refresh chain

1. **`maintenanceProvider` has no reactive dependencies on data changes** — should watch `bodyweightProvider` and `todaysFoodProvider` (or at minimum `resetTriggerProvider` + refetch data).
2. **`_countDataDaysProvider` uses `ref.read` (not `ref.watch`)** — computes once, never recomputes. Should watch `bodyweightProvider` and `todaysFoodProvider`.

### Fix scope

- `maintenance_provider.dart`: add `ref.watch(bodyweightProvider)` and `ref.watch(todaysFoodProvider)` so it fires on weight/food log
- `maintenance_card.dart`: make `_countDataDaysProvider` reactive by watching data providers instead of `ref.read`
- Or alternatively, add `ref.invalidate(maintenanceProvider)` after food and bodyweight log operations. But watching is cleaner (DRY, no missed sites).

### App-level refresh pattern

The only place where the app triggers a mass invalidation is `_onOnboardingComplete()` in `app.dart`, which invalidates `bodyweightProvider`, `todaysFoodProvider`, and `userGoalsProvider`. `maintenanceProvider` is notably absent from this list as well.

---

## 5. Tap recent entry to re-log

### Recent foods data flow

```
food_entries table → db.getRecentFoods()  (database.dart:178–211)
  → distinct foodIds ordered by MAX(loggedAt) DESC, LIMIT 10
  → fetch Food records from foods table
  ↓
recentFoodsProvider  (recent_foods_provider.dart:11–21)
  → wraps in RecentFoodItem { FoodSearchItem food, DateTime lastUsed }
  ↓
_RecentFoodsSection  (food_search_delegate.dart:74–137)
  → ConsumerWidget, watches recentFoodsProvider
  → renders ListTile per item with onTap → close(context, item)
```

### Current behavior on tap

Tapping a recent food flows through the **full selection pipeline**:

1. `_RecentFoodsSection.onTap` → `close(context, item)` returns `FoodSearchItem` to `_onSearch()`
2. `_onSearch()` calls `_selectFood(result)` which sets state: `_selectedFood`, `_servings`, `_unit`
3. UI re-renders with serving picker, macro preview, meal type selector
4. User adjusts serving size (or not), picks meal type, taps Save
5. `_save()` inserts food entry into DB, invalidates `todaysFoodProvider`

There is **no quick-log or duplicate-entry functionality**. Grep for `quickLog`, `duplicateEntry`, `logAgain`, `reLog` — zero results.

### What exists that can be reused

| Component | File | Reuse potential |
|-----------|------|-----------------|
| `FoodSearchDelegate` | `food_search_delegate.dart` | Already shared between log screen and recipe ingredient picker |
| `_RecentFoodsSection` | `food_search_delegate.dart` | Already shared |
| `LogRecipeSheet` | `log_recipe_sheet.dart` | Good UX template — bottom sheet with serving picker + meal type + log button |
| `_save()` logic | `log_food_screen.dart:117–193` | Can be refactored into a reusable method |
| `foodLogProvider.insertEntry()` | `food_log_provider.dart` | CRUD wrapper for inserting a food entry |

### Today's entries — unused `onTap`

In `_TodayEntriesSection` (`log_food_screen.dart:390–528`), each entry's `ListTile` has no `onTap` set — only a delete button (trash icon). This is a natural place to add "duplicate this entry" behavior.

### Recipe ingredient selection

In `recipe_form_screen.dart:70–132`, `_addIngredient()` opens the same `FoodSearchDelegate`. After selecting a food, it shows a `_QuantityDialog` for the ingredient amount. This flow diverges from food logging (recipe ingredients stay in-memory, not persisted immediately), but the recent-foods UI (`_RecentFoodsSection`) is already shared.

### Recommended approach: Quick-log bottom sheet

Add a secondary action to recent food items (e.g., trailing `+` icon or different `onTap` behavior):

1. Create a **`QuickFoodLogSheet`** (modeled on `LogRecipeSheet`) — bottom sheet with:
   - Food name + macro preview (already computed)
   - Serving size field (default = `food.servingQuantity`)
   - Meal type selector
   - "Log to today" button
2. Add an `onQuickLog` callback to `FoodSearchDelegate` and `_RecentFoodsSection`
3. Handle `onQuickLog` in `_LogFoodScreenState` to show the bottom sheet and save

For recipe ingredient picker, a similar quick-add could skip the `_QuantityDialog` and use a default quantity of 1. But this is a separate concern — the recipe context needs discussion.

### Quick-log button on today's entries

Add a trailing duplicate icon on each entry in `_TodayEntriesSection` that creates a copy with a fresh timestamp. This is independent of the recent-foods quick-log and addresses the "eat the same foods frequently" use case from a different angle.

---

## Summary of work items

| # | Issue | Scope | Effort estimate |
|---|-------|-------|-----------------|
| 1 | Remove `servingSizeGrams` field | 8 production files, 6 test files + schema migration | Small |
| 2 | Improve OFF serving size parser | 1 file (`food_result.dart`), new test file | Medium |
| 3 | Fix imperial/metric in protein slider, rate display, height helpers | 4–6 files + `UnitPreferences` additions | Medium |
| 4 | Fix maintenance refresh chain | 2–3 provider files | Small |
| 5 | Add quick-log for recent foods + duplicate entry | 3–4 files, new bottom sheet widget | Medium |
