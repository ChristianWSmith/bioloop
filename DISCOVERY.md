# Discovery Report — bioloop issues

## Contents

1. [Group A: Global unit preference & consistent conversion](#group-a-global-unit-preference--consistent-conversion)
2. [Group B: Arbitrary serving units](#group-b-arbitrary-serving-units)
3. [Group C: Log tab improvements](#group-c-log-tab-improvements)
4. [Group D: Stale bodyweight after reset](#group-d-stale-bodyweight-after-reset)
5. [Group E: App title branding](#group-e-app-title-branding)
6. [Appendix: Full inventory of measurement display sites](#appendix-full-inventory-of-measurement-display-sites)

---

## Group A — Global unit preference & consistent conversion

Issues: **#2, #3, #6, #9, #10**

### Current state

The unit preference (`useImperial`) is stored as `user_goals.use_imperial` (0 = metric, 1 = imperial), persisted in the Drift database alongside other goal fields. There is **no Riverpod provider** that broadcasts the user's unit preference globally — each screen reads it independently from the DB.

### Affected screens

| Screen | Height | Weight | Goal weight | Bodyweight entries | Unit toggle |
|--------|--------|--------|-------------|-------------------|-------------|
| **Onboarding** | Live convert on toggle | Live convert on toggle | Live convert on toggle | N/A | Yes |
| **Goals** | Live convert on toggle | N/A | Live convert on toggle | N/A | Yes |
| **Dashboard** | N/A | Reads kg directly, converts to lb for goal card | Converts using `useImperial` from `userGoalsProvider` | Sparkline converts using `userGoals.useImperial` | N/A (read-only display) |
| **Bodyweight** | N/A | N/A | N/A | **Always shows kg** (hardcoded) | **No toggle** |
| **History export** | N/A | N/A | N/A | Always exports kg | No |

### Bug #9 — Goal weight display bug (confirmed)

**Root cause:** `goals_screen.dart:67`:
```dart
_goalWeightController.text = goals.goalWeightKg?.toString() ?? '';
```

The stored `goalWeightKg` value (always in kg) is loaded into the text field **without converting to imperial**, even when `_useImperial` is set to `true`. The same pattern applies to height (`goals.heightCm?.toString()` at line 66).

The `_loadGoals()` method sets both `_useImperial` (from `goals.useImperial == 1`) and the controller values in the same `setState()`. But the height and goal weight controllers are always populated with raw kg/cm values regardless of the unit setting.

**Compare with onboarding:** Onboarding starts fresh (no goals to load) so it never encounters this bug — it's always entering new data.

### Bug #3 — Imperial height doesn't load upfront (confirmed)

Same root cause as #9. When `_useImperial = true`, the imperial height fields (`_heightFeetController`, `_heightInchesController`) remain empty after `_loadGoals()`, because only `_heightController` is populated (with cm value). The user must toggle to metric (sees the cm), then toggle back to imperial (triggering `_onUnitsChanged` which converts cm → ft/in).

### Issue #6 — Bodyweight logging has no imperial support (confirmed)

**File:** `lib/features/bodyweight/widgets/add_weight_sheet.dart:142`

```dart
suffixText: 'kg',
```

The weight entry field is hardcoded to kg. Display in bodyweight list (`bodyweight_screen.dart:104`):
```dart
title: Text('${entry.weightKg} kg'),
```

The `AddWeightSheet` has **no access** to `useImperial`. The bodyweight list display has **no access** to `useImperial`.

### Issue #10 — Authoritative unit principle

**Problem:** Converting imperial→kg→imperial introduces drift due to floating-point. E.g., 100 lb → 45.3592 kg → 100.1 lb.

**Current approach:** The display-side code in `dashboard_screen.dart:251-252`:
```dart
Text('${current.toStringAsFixed(0)} $unit')
```
Uses `toStringAsFixed(0)` which masks the drift for display, but the underlying value is still drifted. This works for display-only scenarios but would be a problem if the user edits a value that round-tripped.

**Key sites affected:**
- Onboarding: entering weight in lb, converting to kg, storing kg — no round-trip issue (only forward conversion)
- Goals screen: loading kg from DB, converting to imperial for display, user edits and saves — **this is where drift happens**
- Bodyweight: currently always kg, so no round-trip

**Potential approaches:**
1. Store both the user-entered value and the unit it was entered in (separate columns: `goalWeightRaw` + `goalWeightUnit`)
2. Store only kg, always convert via `kg * 2.20462` for display, accept sub-0.1 rounding as imperceptible
3. Store only kg, and when the user unit is imperial, store the user-facing value as a separate field to preserve exact entry

Approach 1 is the cleanest but adds schema columns. Approach 2 works for `toStringAsFixed(0)` display (the 0.1lb drift is invisible) but would show 100.1 if we ever display with decimals.

### Issue #2 — Rounding and global toggle

**Rounding requirement:** "conversions should be rounded to 2 decimal places when displayed. internally they should be stored with arbitrary precision."

**Current rounding context:**

| Context | Current precision | Meets spec? |
|---------|------------------|-------------|
| Goal weight card (dashboard) | `toStringAsFixed(0)` | No (0 dp) |
| Bodyweight sparkline tooltip | `toStringAsFixed(1)` | No (1 dp) |
| Bodyweight list | `weightKg` raw + "kg" — uses Dart default toString | No |
| Onboarding/goals conversion fields | `toStringAsFixed(1)` | No |
| Macros display | `toStringAsFixed(0)` or `toStringAsFixed(1)` | N/A (not a unit conversion) |

### Discovery: What needs a global unit provider

Currently no single source of truth for the user's unit preference. A new `unitPreferencesProvider` (Riverpod provider watching `userGoalsProvider`) could be created. Screens would read this instead of independently querying the DB.

**Provider dependency chain:**
```
userGoalsProvider (FutureProvider)
  └── unitPreferencesProvider (Provider, derived — exposes useImperial + locale)
```

### Discovery: CSV export

`export.dart` hardcodes `weight_kg` column header and raw kg values. If we support imperial bodyweight logging, exports should include a `unit` column or convert to user's preferred unit.

---

## Group B — Arbitrary serving units

Issues: **#4, #8**

### Schema gap

**Current `Foods` table** (`lib/core/database/tables/foods.dart`):

| Column | Type | Purpose |
|--------|------|---------|
| `servingLabel` | text | "100g", "1 cup", "1 slice" |
| `servingSizeGrams` | real? | Grams per serving (nullable) |

**Missing:** A `serving_unit` column (text) to store the unit part of the serving label separately (e.g., "g", "cup", "slice", "piece", "ml", "oz").

**Current `FoodEntries` table** (`lib/core/database/tables/food_entries.dart`):

| Column | Type | Purpose |
|--------|------|---------|
| `servings` | real | Multiplier ("number of servings") |
| `servingLabel` | text | Label snapshot from the food |

**Problem:** `servings` as an abstract multiplier is not intuitive when the serving unit is "cup" or "slice". The user should enter "2" and see "2 cups", not "2 servings of 1 cup".

### OpenFoodFacts parsing gap

**File:** `lib/core/api/models/food_result.dart:80-84`

```dart
static double? _parseServingGrams(String servingSize) {
  final match = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(servingSize);
  if (match != null) return double.parse(match.group(1)!);
  return null;
}
```

Only extracts grams. Non-gram labels return `null` for `servingSizeGrams`, which means the grams input field in the logger is hidden for foods like "1 cup", "1 slice", "1 bar".

**Example API serving sizes seen in the wild:**
- `"100g"` → unit = "g", qty = 100
- `"1 cup (240ml)"` → unit = "cup", qty = 1
- `"1 slice"` → unit = "slice", qty = 1
- `"1 bar (40g)"` → unit = "bar", qty = 1
- `"1 packet"` → unit = "packet", qty = 1
- `"1/2 cup (120ml)"` → unit = "cup", qty = 0.5
- `"1 oz (28g)"` → unit = "oz", qty = 1

**Regex patterns needed for parsing:**
1. Extract quantity + unit from `"1 cup (240ml)"` → `qty=1, unit="cup", gramEquivalent=240`
2. Extract quantity + unit from `"100g"` → `qty=100, unit="g"` (gramEquivalent implied)
3. Extract from `"1 bar (40g)"` → `qty=1, unit="bar", gramEquivalent=40`

### Logging UI rework needed

**File:** `lib/features/logging/widgets/serving_size_picker.dart`

Current: "Servings" stepper + conditional "Grams" text field.

Desired: Quantity input + unit dropdown. The quantity replaces the abstract "servings" concept. The unit is pre-populated from the food's `serving_unit` but user can change it via dropdown (common units) or enter custom text.

**Dropdown options research:**

A set of common units should appear in the dropdown:
- Grams (g)
- Milliliters (ml)
- Fluid ounces (fl oz)
- Ounces (oz)
- Cups
- Tablespoons (tbsp)
- Teaspoons (tsp)
- Slices
- Pieces
- Packets
- Bars
- Servings (as fallback)
- Custom… (opens text field)

### Recipe ingredient rework needed

**File:** `lib/features/recipes/recipe_form_screen.dart:442` (`_QuantityDialog`)

Current dialog label: `"Number of servings"`

This should show the ingredient's unit. For example, if the ingredient's serving label is "1 cup", the dialog should say `"Quantity in cups"` and the stored `quantity` column should represent the number of cups.

**File:** `lib/features/recipes/widgets/recipe_ingredient_row.dart:26`

Current subtitle: `'${ingredient.quantity.toStringAsFixed(1)} × ${food.servingLabel} — ${cals.toStringAsFixed(0)} kcal'`

This already shows the serving label, so the display is mostly correct — the issue is that the quantity dialog asks for "servings" instead of the actual unit.

### Recipe logging rework needed

**File:** `lib/features/recipes/widgets/log_recipe_sheet.dart:100`

Current: `labelText: 'Portion (${recipe.servingLabel})'`

This is already unit-aware (shows the recipe's serving label). The issue is that when logging, the `servings` field in the food entry is set to the scale factor (e.g., 0.5 for half a recipe), not the actual portion amount. This makes the edit UI confusing.

### Manual food form rework

**File:** `lib/features/logging/widgets/manual_food_form.dart:121-131`

Current: free-text "Serving label" field (e.g., "1 cup", "1 slice"). No unit dropdown.

The form should offer a quantity field + unit dropdown, which together produce the serving label. E.g., quantity=2 + unit="cups" → servingLabel = "2 cups", or quantity=1 + unit="slice" → servingLabel = "1 slice".

### Migration strategy

A schema migration (bump `schemaVersion` from 1 to 2 in `database.dart:32`) would add:
- `Foods.serving_unit` text column
- Optionally: `Foods.serving_quantity` real column (to store the quantity part separately)

For existing data:
- `servingSizeGrams != null` → unit = "g"
- `servingLabel` contains "cup" → unit = "cup"
- Otherwise → unit = "serving" (fallback)

---

## Group C — Log tab improvements

Issues: **#5, #11**

### Issue #5 — Manual deletion of logged food items

**Current state:** `FoodEntry` deletion **already exists** in the history screen (`history_screen.dart:240-296`). Users can swipe-to-delete with confirmation dialog. The `deleteEntry(int id)` DAO method is in `database.dart:143-145`.

**Gap:** The deletion UX is only in the **History tab** (paginated, all entries). It's **not available on the Dashboard tab** (today's entries) or **Log tab** (which has no entry list at all — it's purely for creating new entries).

**Dashboard today's entries:** The dashboard screen sums today's macros into rings but does NOT show a list of individual entries. The user cannot see or delete individual logged items from today without switching to the History tab.

**Possible UX solutions:**
1. Show a "Today's entries" expandable list on the Dashboard (below macro rings)
2. Show today's entries on the Log tab (above the search bar, in recency order)
3. Both

**Query already exists:** `todaysFoodProvider` returns `getEntriesForDate(today)`. This can power a today's-entry list on any screen.

### Issue #11 — Recent foods

**No mechanism exists.** Every search is a fresh lookup against the local `foods` table + OpenFoodFacts API. There's no recency-sorted list, no frequency tracking, and no separate recent-foods table.

**Simplest implementation (no schema change):**

Query `food_entries` GROUP BY `foodId`, `name`, `servingLabel` ORDER BY MAX(`loggedAt`) DESC:

```sql
SELECT foodId, name, servingLabel, MAX(loggedAt) as lastUsed
FROM food_entries
WHERE foodId IS NOT NULL
GROUP BY foodId, name, servingLabel
ORDER BY lastUsed DESC
LIMIT 10
```

This returns the last 10 distinct foods logged (excluding those with `foodId IS NULL`, which are ad-hoc entries without a backing food record).

**Alternative (new table):** `recent_foods` table with columns `food_id`, `last_used_at`, `use_count`. Updated on every food log. Would require:
- Schema migration (bump to v2 or v3)
- Write on every `insertEntry()`
- Pruning old entries

**Integration point:** The `FoodSearchDelegate` (`food_search_delegate.dart`) shows results only when query is non-empty (`if (query.isNotEmpty)`). Recent foods should appear when the query is EMPTY (initial search state). The delegate's `buildSuggestions` method could show recent foods in place of the empty-state hint.

Alternatively (if the user doesn't want to open the search delegate): show recent foods as inline tiles on the **Log tab** directly, above the search bar. This gives one-tap access without opening search.

### Data model for recent foods

Both approaches share the same data shape:
```dart
class RecentFood {
  final int? foodId;
  final String name;
  final String servingLabel;
  final double? servingSizeGrams;
  final double caloriesPerServing;
  final double proteinPerServing;
  final double carbsPerServing;
  final double fatPerServing;
  final String? barcode;
  final String source;
  final DateTime lastUsed;
}
```

This mirrors `FoodSearchItem` but adds `lastUsed`.

---

## Group D — Stale bodyweight after reset

Issue: **#7**

### Root cause (confirmed)

**File:** `lib/core/database/database.dart:302-312` (`resetAll()`)

Reset truncates all tables including bodyweight_entries.

**File:** `lib/app.dart:52`
```dart
ref.listen<int>(resetTriggerProvider, (_, _) {
  _checkOnboarding();
});
```

The reset-trigger listener only calls `_checkOnboarding()` — it does NOT invalidate any providers.

**File:** `lib/app.dart:46-48`
```dart
void _onOnboardingComplete() {
  setState(() => _onboardingCompleted = true);
}
```

Onboarding completion only sets state on App — does NOT invalidate `bodyweightProvider`.

**The stale-state trace:**
1. `resetAll()` truncates bodyweight_entries → `resetTriggerProvider` incremented → `bodyweightProvider` re-resolves → **empty list**
2. `_checkOnboarding()` → onboarding screen shown
3. User completes onboarding → `db.insertWeight()` called directly (not through provider) → new weight saved to DB
4. `_onOnboardingComplete()` → `_appShell` shown with `BodyweightScreen` → `bodyweightProvider` still holds **cached empty list** from step 1
5. Only a full app restart re-resolves `bodyweightProvider`, which then finds the new weight

### Fix needed

After onboarding completes, `bodyweightProvider` must be invalidated:

```dart
void _onOnboardingComplete() {
  ref.invalidate(bodyweightProvider);  // <-- ADD THIS
  setState(() => _onboardingCompleted = true);
}
```

Alternatively, invalidate all data providers as a bulk action after onboarding. This also ensures the dashboard/macro targets refresh with the new bodyweight data.

### Comparison to existing patterns

In `bodyweight_screen.dart:118` and `145`, `ref.invalidate(bodyweightProvider)` is called after logging/editing/deleting a weight — the pattern already exists, just not applied after onboarding.

---

## Group E — App title branding

Issue: **#1**

### Current title locations

| Location | File | Current value | Needs change |
|----------|------|---------------|-------------|
| Flutter MaterialApp title | `lib/app.dart:57` | `'bioloop'` | `'BioLoop'` |
| Android manifest | `android/app/src/main/AndroidManifest.xml:4` | `android:label="bioloop"` | `android:label="BioLoop"` |
| iOS BundleDisplayName | `ios/Runner/Info.plist:12` | `Bioloop` (note: already PascalCase) | `BioLoop` |
| iOS BundleName | `ios/Runner/Info.plist:20` | `bioloop` | `BioLoop` |
| Dashboard welcome text | `dashboard_screen.dart:188` | `'Welcome to bioloop'` | `'Welcome to BioLoop'` |

### Notes

- iOS `CFBundleDisplayName` is already `Bioloop` (partial stylization, missing capital L).
- The Android `android:label` is used for the launcher app name under the icon.
- The Flutter `MaterialApp.title` is used for the window title (desktop) and task switcher.
- The dashboard welcome text is a secondary branding touchpoint.
- `pubspec.yaml` may also reference the name but that's the package identifier, not user-facing.

---

## Appendix: Full inventory of measurement display sites

Comprehensive catalog of every location where a measurement value (weight, height, serving) is displayed or entered, with current unit handling.

### Onboarding screen (`lib/features/onboarding/onboarding_screen.dart`)

| Field | Stored as | Display unit | Unit conversion | Bug? |
|-------|-----------|-------------|-----------------|------|
| Height | cm | cm or ft/in | Live toggle via `_onUnitsChanged` | No |
| Starting weight | kg | kg or lb | Live toggle via `_onUnitsChanged` | No |
| Goal weight | kg | kg or lb | Live toggle via `_onUnitsChanged` | No |

**Saving:** All converted to metric before `upsertGoals()`.

### Goals screen (`lib/features/goals/goals_screen.dart`)

| Field | Stored as | Display unit | Unit conversion | Bug? |
|-------|-----------|-------------|-----------------|------|
| Height | cm | cm or ft/in | `_loadGoals` loads raw cm; only toggling units converts. **No upfront conversion.** | **#3 — Yes** |
| Goal weight | kg | kg or lb | `_loadGoals` loads raw kg; only toggling converts. **No upfront conversion.** | **#9 — Yes** |

### Dashboard screen (`lib/features/dashboard/dashboard_screen.dart`)

| Element | Display unit | Conversion | Bug? |
|---------|-------------|-----------|------|
| Goal weight card | kg or lb | `useImperial ? 2.20462 : 1.0` | No (reads `goals.useImperial`) |
| Rate card | Always lb/week | Hardcoded `lb/week` text | Minor — always lb regardless of preference |
| Macro rings | Always g / kcal | None (macros are unitless) | No |

### Bodyweight sparkline (`lib/features/dashboard/widgets/bodyweight_sparkline.dart`)

| Element | Display unit | Conversion | Bug? |
|---------|-------------|-----------|------|
| Chart Y-axis | kg or lb | `useImperial ? 2.20462 : 1.0` at line 43 | No (reads `userGoalsProvider`) |
| Tooltip | kg or lb | `useImperial` check at line 135 | No |

### Bodyweight screen (`lib/features/bodyweight/bodyweight_screen.dart`)

| Element | Display unit | Conversion | Bug? |
|---------|-------------|-----------|------|
| List items | **Always kg** | None | **#6 — Always hardcoded kg** |
| Delete confirmation | **Always kg** | None | **#6 — Always hardcoded kg** |
| CSV export | Always kg | None | Acceptable |

### AddWeightSheet (`lib/features/bodyweight/widgets/add_weight_sheet.dart`)

| Element | Display unit | Conversion | Bug? |
|---------|-------------|-----------|------|
| Input field suffix | **Always "kg"** | None | **#6 — Always hardcoded kg** |

### Logging — Serving size picker (`lib/features/logging/widgets/serving_size_picker.dart`)

| Element | Current behavior | Need per #4 |
|---------|-----------------|-------------|
| Stepper | "Servings" (abstract multiplier) | Quantity + unit dropdown |
| Grams input | Only shown when `servingSizeGrams != null` | Remove; replace with unit-aware input |

### Recipe ingredient quantity dialog (`lib/features/recipes/recipe_form_screen.dart:442`)

| Element | Current label | Desired label |
|---------|--------------|--------------|
| Quantity dialog | `"Number of servings"` | `"Quantity in {unit}"` |

### Recipe ingredient row (`lib/features/recipes/widgets/recipe_ingredient_row.dart:26`)

| Element | Current display | Issue |
|---------|----------------|-------|
| Subtitle | `'Qty × servingLabel — kcal'` | Already shows unit; only the dialog label is wrong |

### Edit entry sheet (`lib/features/history/widgets/edit_entry_sheet.dart`)

| Field | Current | Issue |
|-------|---------|-------|
| Servings | Raw number, no unit label | Could show the stored `servingLabel` for context |

### History export (`lib/features/history/export.dart`)

| File | Columns | Units |
|------|---------|-------|
| Food CSV | `date,meal_type,name,servings,calories,protein_g,carbs_g,fat_g` | Always g, always kcal |
| Bodyweight CSV | `date,weight_kg` | Always kg |

### CSV export — most location needs

If bodyweight entries can be logged in imperial, the export should include a unit indicator column or convert. However, storing in kg and always exporting in kg is arguably the correct approach for data interchange (kg is the standard).

### Manual food form (`lib/features/logging/widgets/manual_food_form.dart`)

| Field | Current | Need per #4 |
|-------|---------|-------------|
| Serving label | Free text | Quantity + unit dropdown |
| Serving size grams | Optional free text | Should auto-compute from unit selection when possible |

---

## Schema migration summary

| Table | Current columns | Proposed additions |
|-------|----------------|-------------------|
| `foods` | `servingLabel`, `servingSizeGrams` | `servingUnit` text, `servingQuantity` real |
| `food_entries` | `servings`, `servingLabel` | Optional: `quantity` real, `unit` text |
| `user_goals` | `useImperial` | Optional: `goalWeightRaw` real, `goalWeightUnit` text (for #10 authoritative principle) |
| New: `recent_foods` | — | `foodId`, `lastUsedAt`, `useCount` (optional — may use query-only approach instead) |

Bump `schemaVersion` from 1 to 2 (or 3 if multiple migration steps). Use Drift's `MigrationStrategy` with `onUpgrade` callback.
