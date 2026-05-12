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
    api/
      open_food_facts_client.dart     # REST client for food search/barcode
    algorithms/
      maintenance_calculator.dart     # Rolling linear regression
  features/
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
    bodyweight/
      bodyweight_screen.dart
      widgets/
        weight_chart.dart
        add_weight_sheet.dart
    history/
      history_screen.dart
    goals/
      goals_screen.dart
  providers/
    database_provider.dart
    food_log_provider.dart
    bodyweight_provider.dart
    goals_provider.dart
    maintenance_provider.dart
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
  updated_at            TEXT NOT NULL
);
```

---

## 2. Feature Phases

### Phase 1 — Foundation
- Set up drift database with all four tables
- Set up Riverpod providers (database, per-feature)
- App shell with bottom navigation: Dashboard, Log, Bodyweight, History, Goals
- Material 3 theme (dark + light)

### Phase 2 — Core Logging
- **OpenFoodFacts client:** search by name, fetch by barcode
- **Local food cache:** API results auto-save to `foods` table on selection; search queries local `foods` first (instant), then hits API — merged & deduplicated by barcode
- **Manual food creation:** form inside log flow — name, serving label, macros per serving, optional gram weight. Saves to `foods` (`source = 'manual'`), usable in search thereafter
- **Log food screen:** search local cache + API → pick result → adjust servings (or grams if `serving_size_grams` known) → select meal type → save as snapshot in `food_entries`
- **Bodyweight logging:** bottom sheet with date picker + weight field
- **Food history screen:** paginated by date, swipe-to-delete

### Phase 3 — Dashboard & Targets
- **Dashboard:** macro progress rings (protein/carbs/fat), calories remaining, bodyweight sparkline, maintenance calorie card, estimated rate of loss/gain
- **Goals screen:** goal type (cut/maintain/bulk), calorie deficit/surplus input with rate preview ("~1 lb/week loss"), protein g/lb slider (hint: 0.8–1.4), fat % slider with shaded 20–35% recommended band
- **Macro target calculation:** see §4 for full detail

### Phase 4 — Maintenance Algorithm
- Rolling regression in `maintenance_calculator.dart`:
  1. Build daily aggregates `(date, cals, weight)` for rolling window
  2. Smooth weight via 7-day centered linear regression → `Δweight/day`
  3. Regress `Δweight ~ calories` → maintenance = x-intercept (`Δweight=0`)
  4. Minimum 14 data points; show confidence interval
- Provider caches result, recomputes on new food/weight insert

### Phase 5 — Polish (future)
- Barcode scanning via `camera` + MLKit
- CSV data export
- Meal templates / favorites

---

## 3. Dependencies

| Package | Purpose |
|---------|---------|
| `drift` + `sqlite3_flutter_libs` | Database ORM |
| `riverpod` + `flutter_riverpod` | State management |
| `fl_chart` | Charts |
| `http` | API calls |
| `intl` | Formatting |
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
  if maintenance_calories != null:
    target_calories = maintenance_calories + calorie_adjustment
  else:
    target_calories = calorie_adjustment   (absolute floor)

Step 2 — Protein:
  protein_g   = bodyweight_lb × protein_g_per_lb
  protein_cal = protein_g × 4

Step 3 — Fat:
  fat_cal     = target_calories × (fat_pct / 100)
  fat_g       = fat_cal / 9

Step 4 — Carbs (fills remainder):
  carbs_cal   = target_calories − protein_cal − fat_cal
  carbs_g     = carbs_cal / 4

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

---

## 6. Open Decisions

| Question | Decision |
|----------|----------|
| Navigation | go_router vs simple state-based — app has few screens, simple works |
| Unit display | kg internally, lb optional on output |
| Testing | Write alongside features or defer? |
| Barcode scanning | Phase 5 (requires camera permission) |
