# bioloop — Implementation Plan

## Overview

A Flutter macro counter that auto-adjusts daily targets based on bodyweight trends. Uses rolling regression to derive maintenance calories from logged food + weight data.

**Tech stack:** Flutter / drift / Riverpod / OpenFoodFacts API

---

## Architecture

```
lib/
  main.dart                           # ProviderScope, runApp
  app.dart                            # MaterialApp + bottom nav shell
  core/
    database/
      database.dart                   # AppDatabase (drift)
      tables/
        foods.dart
        food_entries.dart
        bodyweight_entries.dart
        user_goals.dart
        meal_templates.dart

    api/
      open_food_facts_client.dart     # REST client for food search/barcode
      models/
        food_result.dart              # API response deserialization
    algorithms/
      maintenance_calculator.dart     # Rolling linear regression
      mifflin_st_jeor.dart            # Mifflin-St Jeor BMR estimator (pure function, no deps)
  features/
    onboarding/
      onboarding_screen.dart          # First-launch setup (T2b)
    dashboard/
      dashboard_screen.dart
      widgets/
        macro_ring.dart
        maintenance_card.dart
        bodyweight_sparkline.dart
    logging/
      log_food_screen.dart
      widgets/
        food_search_delegate.dart
        serving_size_picker.dart
        meal_type_selector.dart
        manual_food_form.dart
        barcode_scanner.dart
        meal_templates.dart           # Template/recipe list (T16)
    bodyweight/
      bodyweight_screen.dart
      widgets/
        weight_chart.dart
        add_weight_sheet.dart
    history/
      history_screen.dart
      export.dart                    # CSV export (T16)
    goals/
      goals_screen.dart
    settings/
      settings_screen.dart
  providers/
    database_provider.dart
    food_log_provider.dart            # includes todaysFoodProvider (T6)
    food_search_provider.dart         # local + API merged search (T4)
    bodyweight_provider.dart
    goals_provider.dart
    onboarding_provider.dart          # onboarding CRUD, separate from goals (T2b)
    macro_targets_provider.dart       # daily macro computations (T10)
    maintenance_provider.dart         # regression result (stub in T10, real in T13)
  theme/
    theme.dart
```

---

## 1. Database Schema (drift)

```sql
CREATE TABLE foods (                      -- searchable reference / cache
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  name                  TEXT NOT NULL,
  serving_label         TEXT NOT NULL,     -- e.g. "1 cup (240ml)", "100g", "1 slice"
  serving_size_grams    REAL,              -- nullable; enables gram-based scaling
  calories_per_serving  REAL NOT NULL,
  protein_per_serving   REAL NOT NULL,
  carbs_per_serving     REAL NOT NULL,
  fat_per_serving       REAL NOT NULL,
  barcode               TEXT UNIQUE,
  source                TEXT NOT NULL DEFAULT 'manual',  -- 'open_food_facts' | 'manual'
  created_at            TEXT NOT NULL
);
CREATE INDEX idx_foods_name ON foods(name);

CREATE TABLE food_entries (               -- immutable daily log (denormalized snapshot)
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL,
  calories        REAL NOT NULL,           -- total, already scaled to servings
  protein_grams   REAL NOT NULL,           -- total, already scaled
  carbs_grams     REAL NOT NULL,           -- total, already scaled
  fat_grams       REAL NOT NULL,           -- total, already scaled
  servings        REAL NOT NULL,           -- number of servings logged
  serving_label   TEXT NOT NULL,           -- display text from food
  barcode         TEXT,
  food_id         INTEGER REFERENCES foods(id),
  meal_type       TEXT NOT NULL,           -- breakfast | lunch | dinner | snack
  logged_at       TEXT NOT NULL            -- ISO-8601
);

CREATE TABLE bodyweight_entries (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  weight_kg       REAL NOT NULL,
  logged_at       TEXT NOT NULL
);

CREATE TABLE user_goals (                  -- singleton row (id=1)
  id                    INTEGER PRIMARY KEY DEFAULT 1,
  goal_type             TEXT NOT NULL,     -- cut | maintain | bulk
  calorie_adjustment    REAL,              -- deficit/surplus: e.g. -500, 0, +300
  protein_g_per_lb      REAL DEFAULT 1.0,
  fat_calorie_pct       REAL DEFAULT 25.0, -- % of calories from fat
  sex                   TEXT,                -- 'male' | 'female'; null until onboarding
  height_cm             REAL,                -- null until onboarding
  age                   INTEGER,             -- null until onboarding
  goal_weight_kg        REAL,                -- target bodyweight; null until set
  use_imperial          INTEGER NOT NULL DEFAULT 0, -- 0=kg/cm, 1=lb/ft/in
  activity_level        INTEGER NOT NULL DEFAULT 3, -- 1=sedentary … 5=extra active
  onboarding_completed  INTEGER NOT NULL DEFAULT 0,
  updated_at            TEXT NOT NULL
);

CREATE TABLE meal_templates (               -- templates + recipes (added in T1, used in T16)
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL,
  type        TEXT NOT NULL DEFAULT 'template',  -- 'template' | 'recipe'
  foods       TEXT NOT NULL,       -- JSON array of ingredient snapshots
  created_at  TEXT NOT NULL
);
```

---

## 2. Feature Phases

### Phase 1 — Foundation
- Set up drift database with all five tables
- Set up Riverpod providers (database, per-feature)
- App shell with bottom navigation: Dashboard, Log, Bodyweight, History, Goals
- Material 3 theme (dark + light)
- Onboarding flow — sex, age, height, starting weight, activity level, initial goals

### Phase 2 — Core Logging
- **OpenFoodFacts client:** search by name, fetch by barcode
- **Local food cache:** API results auto-save to `foods` table on selection; search queries local `foods` first (instant), then hits API — merged & deduplicated by barcode
- **Manual food creation:** form inside log flow — name, serving label, macros per serving, optional gram weight. Saves to `foods` (`source = 'manual'`), usable in search thereafter
- **Log food screen:** search local cache + API → pick result → adjust servings (or grams if `serving_size_grams` known) → select meal type → save as snapshot in `food_entries`
- **Bodyweight logging:** bottom sheet with date picker + weight field; tap to edit existing entries
- **Food history screen:** paginated by date, swipe-to-delete, tap-to-edit

### Phase 3 — Dashboard & Targets
- **Dashboard:** macro progress rings (protein/carbs/fat), calories remaining, bodyweight sparkline, maintenance calorie card, estimated rate of loss/gain, goal weight delta
- **Goals screen:** goal type (cut/maintain/bulk), calorie deficit/surplus input with rate preview ("~1 lb/week loss"), goal weight field, units toggle (kg/lb, cm/ft), protein g/lb slider (hint: 0.8–1.4), fat % slider with shaded 20–35% recommended band
- **Macro target calculation:** see §4 for full detail; Mifflin-St Jeor estimator lives in a standalone utility (`mifflin_st_jeor.dart`) consumed directly by T10 (no phase dependency on T13)

### Phase 4 — Maintenance Algorithm
- Rolling regression in `maintenance_calculator.dart`:
  1. Build daily aggregates `(date, cals, weight)` for rolling window
  2. Smooth weight via 7-day centered linear regression → `Δweight/day`
  3. Regress `Δweight ~ calories` → maintenance = x-intercept (`Δweight=0`)
  4. Minimum 14 data points; show confidence interval
- Provider caches result, recomputes on new food/weight insert

### Phase 5 — Polish (future)
- **Barcode scanning** via `camera` + MLKit
- **CSV export + meal templates + recipe builder:** CSV export (food + bodyweight), meal templates (named groups of foods that can be logged in one tap), and recipe builder (save a composite dish with ingredient quantities)
- **Data reset option** — wipe all data and start fresh, accessible from settings

---

## 3. Dependencies

| Package | Purpose |
|---------|---------|
| `drift` + `sqlite3_flutter_libs` | Database ORM |
| `riverpod` + `flutter_riverpod` | State management |
| `fl_chart` | Charts |
| `http` | API calls |
| `intl` | Formatting |
| `path_provider` | Database file path |
| `share_plus` | CSV export share sheet (T16) |
| `mobile_scanner` | Barcode scanning (T15) |
| `camera` | Camera access (T15) |
| `go_router` | Navigation (optional) |

---

## 4. Macro Targets & Recommended Ranges

```
Inputs:
  bodyweight_lb
  maintenance_calories    (from rolling regression, or null)
  calorie_adjustment      (user-set deficit/surplus)
  protein_g_per_lb        (user-set, range 0.8–1.4)
  fat_pct                 (user-set % of calories, range 15–50%)

Step 1 — Calorie target:
  if regression_maintenance != null:
    target_calories = regression_maintenance + calorie_adjustment
  else if onboarding_completed:
    estimated_maintenance = estimateMaintenance(sex, weight_kg, height_cm, age, activity_level)
    target_calories = estimated_maintenance + calorie_adjustment
  else:
    target_calories = max(calorie_adjustment, 1200)   // safe floor before onboarding

Step 2 — Protein:
  protein_g   = bodyweight_lb × protein_g_per_lb
  protein_cal = protein_g × 4

Step 3 — Fat:
  fat_cal     = target_calories × (fat_pct / 100)
  fat_g       = fat_cal / 9

Step 4 — Carbs (fills remainder):
  carbs_cal   = target_calories − protein_cal − fat_cal
  carbs_g     = carbs_cal / 4

### Fallback formula (Mifflin-St Jeor)

Used when rolling regression lacks sufficient data (<14 paired days):

```
male:   BMR = 10 × weight_kg + 6.25 × height_cm − 5 × age + 5
female: BMR = 10 × weight_kg + 6.25 × height_cm − 5 × age − 161

estimated_maintenance = BMR × activity_multiplier[activity_level]
```

The activity multiplier is selected by the user during onboarding. Only applies
to the formula fallback — once regression data is sufficient, the formula is
not used.

| Level | Label | Multiplier | Heuristic |
|-------|-------|-----------|-----------|
| 1 | Sedentary | 1.2 | Little to no exercise, desk job |
| 2 | Lightly active | 1.375 | Light exercise 1–3 days/week |
| 3 | Moderately active | 1.55 | Moderate exercise 3–5 days/week |
| 4 | Active | 1.725 | Hard exercise 6–7 days/week |
| 5 | Extra active | 1.9 | Very hard exercise + physical job |

Default is 3 (moderate) — matches the original fixed multiplier.

Rate preview:
  rate_lbs_per_week = calorie_adjustment × 7 / 3500
  e.g., −500 → "~1 lb/week loss"    +300 → "~0.6 lb/week gain"
```

### Recommended Ranges

| Macro | Source | Range | Behavior |
|-------|--------|-------|----------|
| Protein | Sports nutrition literature | 0.8–1.4 g/lb bodyweight | User sets exact g/lb; app shows range hint |
| Fat | AMDR (Institute of Medicine) | 20–35% of calories | UI shades 20–35% band on slider; warns if outside but allows it |
| Carbs | — | fills remainder | Auto-calculated, no user input |

### Goals Screen UI

- Goal type: segmented button (cut / maintain / bulk)
- Calorie adjustment: number input with live rate preview below it
- Protein: slider 0.5–2.0 g/lb, with current value and range indicator (0.8–1.4)
- Fat: slider 10–50% with shaded healthy band (20–35%), app shows g equivalent alongside %

---

## 5. Maintenance Algorithm Detail

```
For each day d in lookback window (default 30 days):
  cals[d]    = SUM food_entries.calories WHERE date = d
  weight[d]  = bodyweight_entries.weight_kg WHERE date = d

Smooth weight via OLS over ±3 day window → daily_weight_change[d]
Filter to days where both cals[d] and daily_weight_change[d] exist
If count < 14: return null

OLS: daily_weight_change ~ calories
  slope     = cov(cals, changes) / var(cals)
  intercept = mean(changes) - slope * mean(cals)
  maintenance = -intercept / slope
```

Display: *"2,450 kcal (±180, based on 22 days of data)"*

### Fallback: Mifflin-St Jeor estimate

Before the user has enough data (≥14 paired days), maintenance is estimated via the
Mifflin-St Jeor equation with an activity multiplier chosen by the user.

The function `estimateMaintenance(sex, weightKg, heightCm, age, activityLevel)` lives in
`lib/core/algorithms/mifflin_st_jeor.dart`. See T10 for the implementation.

This runs automatically whenever the regression returns null and the user has
completed onboarding. The result is used in place of `maintenance_calories` in
the macro target calculation (§4).

---

## 6. Error Handling & UX Philosophy

### Prevent errors before they happen
- **Disable, don't validate-after-the-fact**. If a form requires a field, keep the submit button disabled until the field is filled. If a meal type must be chosen, disable "Save" until one is selected. Users should never tap a button only to see an error.
- **Good defaults**: pre-select sensible values (e.g. activity level = 3/moderate, meal type = snack) wherever ambiguous.
- **Guard rails**: protein slider clamped 0.5–2.0, fat slider clamped 10–50%. The slider physically cannot leave range.

### When errors do happen (network, DB, constraint violations)
- Show a **dialog** (not a snackbar, not inline text). Title explains what went wrong, body gives the technical gist, one dismiss button: "OK".
- Dialogs are modal — the user must acknowledge. This ensures they see the error.
- Never silently swallow errors. Every DB write, API call, or camera operation that fails must show a dialog.

### Exceptions
- Loading states use skeleton shimmers / spinners (no error dialog for transient loading).
- Empty states are inline UI (no dialog for "no data").
- Deletion shows a confirmation dialog (prevention, not error).

---

## 7. Open Decisions

| Question | Decision |
|----------|----------|
| Navigation | go_router vs simple state-based — app has few screens, simple works |
| Unit display | kg internally, configurable display toggle (`user_goals.use_imperial`) — lb/ft/in on output when enabled |
| Testing | Write alongside features or defer? |
| Barcode scanning | Phase 5 (requires camera permission) |
| Fallback maintenance formula | Mifflin-St Jeor × user-chosen activity multiplier (1–5, default moderate) set during onboarding; data-driven regression replaces it once ≥14 paired days exist |
| Edit entries | Phase 2 MVP — tap-to-edit for both bodyweight and food entries (not deferred) |
| Recipe builder | Integrated with T16 meal templates — a "recipe" is a named group of foods with quantities |
| Data reset | Phase 5 — simple nuke-all-tables button (not a priority for early phases) |
| "Today" boundary | Calendar date from device local time (not rolling 24h window) |
