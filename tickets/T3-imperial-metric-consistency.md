# T3: Honor imperial/metric in all displayed values

## Context & Discovery

The app lets users choose imperial or metric units, but several display surfaces ignore this preference entirely.

**Violations found** (from DISCOVERY.md §3):

1. **Protein slider** always shows `g/lb` — protein slider labels, recommended range, and preview all hardcoded to `g/lb` regardless of user preference.
   - Files: `goals_screen.dart:503,511,515`, `onboarding_screen.dart:522,530,534`
   - DB column `user_goals.proteinGPerLb` stores values in g/lb internally — this is fine, just the UI display needs conversion

2. **Weight change rate** always shows `lb/week` — the rate preview in goals, onboarding, and dashboard all hardcode `lb/week`.
   - Files: `goals_screen.dart:122-123`, `onboarding_screen.dart:66-67`, `dashboard_screen.dart:298-315`
   - Dashboard uses a hardcoded threshold `0.3` (imperial value) that needs a metric equivalent

3. **Height conversion** uses inline raw factors — height fields convert with ad-hoc `2.54`, `30.48` constants instead of going through `UnitPreferences`.
   - Files: `goals_screen.dart:69-73,200-206,242-245`, `onboarding_screen.dart:119-141,176-179,245-248`

4. **CSV export** always writes `kg` — regardless of user preference.
   - File: `history/export.dart:30-33`

**What already works correctly:**
- Weight display (bodyweight screen, sparkline, goal weight card) — uses `UnitPreferences.displayWeight()`
- Macro values (always in g/kcal per design rules)

**What `UnitPreferences` currently lacks:**

| Missing helper | Purpose |
|---------------|---------|
| `displayHeight(double cm)` / `heightCm(double display)` | Convert between cm and imperial height |
| `rateFactor` / `rateUnit` | `'kg/week'` vs `'lb/week'` |
| `proteinDisplayFactor` / `proteinUnit` | `'g/kg'` vs `'g/lb'` |
| `displayProteinGPerLb(double)` / `proteinGPerLbFromDisplay(double)` | Convert between display value and DB storage |

## Intent

Make every displayed value respect the user's imperial/metric preference. Protein slider shows `g/kg` for metric users, weight change rate shows `kg/week`, height conversion uses `UnitPreferences`, and CSV export uses the user's chosen unit. Macros (grams) and calories (kcal) remain unit-agnostic per design rules.

## Acceptance Criteria

1. **`UnitPreferences`** gains: `displayHeight()`, `heightCm()`, `rateFactor`, `rateUnit`, `proteinDisplayFactor`, `proteinUnit`, `displayProteinGPerLb()`, `proteinGPerLbFromDisplay()`

2. **Protein slider** adapts to user preference:
   - Imperial: shows `g/lb`, range 0.5–2.0 (unchanged)
   - Metric: shows `g/kg`, range 1.1–4.4 (equivalent to 0.5–2.0 g/lb)
   - DB still stores as g/lb; UI converts on read/write
   - Recommended range text also adapts: `"0.8-1.4 g/lb"` → `"1.8-3.1 g/kg"`

3. **Weight change rate** adapts to user preference:
   - Imperial: `"~X lb/week loss/gain"` (unchanged)
   - Metric: `"~X kg/week loss/gain"` (rate / 2.20462)
   - Dashboard threshold `0.3` → conditional: `0.3 lb` vs `0.136 kg`

4. **Height fields** use `UnitPreferences.displayHeight()` and `heightCm()` instead of inline raw `2.54`/`30.48` factors — no behavior change, just refactored to use the shared helper

5. **CSV export** uses `prefs.weightUnit` instead of hardcoded `'kg'`

6. `flutter analyze` passes with zero issues
7. All existing tests pass
8. Metric user flow sees `g/kg`, `kg/week`, `cm`; Imperial user flow is unchanged

## Files to modify

| File | Change |
|------|--------|
| `lib/providers/unit_preferences_provider.dart` | Add 8 new helpers (see above) |
| `lib/features/goals/goals_screen.dart` | Adapt protein slider labels + range; adapt rate display; use height helpers |
| `lib/features/onboarding/onboarding_screen.dart` | Same as goals |
| `lib/features/dashboard/dashboard_screen.dart` | Adapt rate display + threshold |
| `lib/features/history/export.dart` | Use `prefs.weightUnit` |

### How protein conversion works

- DB column `proteinGPerLb` stores the value in g/lb (always)
- For metric display: `displayGPerKg = storedGPerLb * 2.20462`
- For metric save: `storedGPerLb = displayGPerKg / 2.20462`
- Slider range for metric: `displayProteinGPerLb(0.5)` to `displayProteinGPerLb(2.0)` = 1.1 to 4.4 g/kg

### How rate conversion works

- `macroTargetsProvider` computes `rateLbsPerWeek` internally (always lb)
- For metric display: `rateKgPerWeek = rateLbsPerWeek / 2.20462`
- `rateStr` formatting should use `prefs.rateFactor`
- Dashboard threshold: `if (rate * (useImperial ? 1 : 1/2.20462) < 0.3 * (useImperial ? 1 : 1/2.20462))`

## Testing

1. `flutter test > test.log 2>&1` — all pass
2. `flutter analyze > analyze.log 2>&1` — zero issues
3. Manual: Set units to metric → verify protein slider shows `g/kg` with range ~1.1–4.4 → verify rate shows `kg/week` → verify CSV export uses `kg` or `lb` based on preference
4. Manual: Set units to imperial → verify no regressions in protein slider, rate display, CSV
5. Verify height fields work identically before and after (no behavior change, just refactored to use `UnitPreferences`)
