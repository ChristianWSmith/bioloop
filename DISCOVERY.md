# Discovery — Issues Resolution Plan

## Issue Inventory (from `issues.txt`)

| # | Category | Description |
|---|----------|-------------|
| 1-4 | Dashboard Sparklines | Timespan sync, data-range fallback, today inclusion, single-point extension |
| 5-7 | OpenFoodFacts API | Empty-result retries, silent failure retry, debounce/dup prevention, toggle-triggered search |
| 8-9 | Food Search UX | Back navigation from custom food, redundant delete button |
| 10 | Recipe Management | Redundant delete button |
| 11 | Macro Settings | Protein basis toggle (g/lb bodyweight vs g/cm height) |

---

## 1. Dashboard Sparklines (Issues #1-4)

### Current Architecture

**Files:**
- `lib/features/dashboard/dashboard_screen.dart` — parent screen, passes `entries` to both sparklines
- `lib/features/dashboard/widgets/bodyweight_sparkline.dart` — weight chart (272 lines)
- `lib/features/dashboard/widgets/calories_sparkline.dart` — calorie chart (185 lines)
- `lib/providers/dashboard_time_range_provider.dart` — `enum TimeRange { oneMonth, sixMonths, allTime }`
- `lib/providers/food_log_provider.dart` — defines `historicalCaloriesProvider` (lines 48-63)
- `lib/providers/bodyweight_provider.dart` — defines `bodyweightProvider` (returns ALL weight entries)

**Data flow:**
```
DashboardScreen
  ├── ref.watch(bodyweightProvider) → all weight entries (no date filter)
  ├── ref.watch(historicalCaloriesProvider) → last 30 days of food entries (HARD-CODED)
  └── ref.watch(dashboardTimeRangeProvider) → TimeRange enum
       ├── BodyweightSparkline(entries: weights) — computes own time range
       └── CaloriesSparkline(entries: historicalCals) — computes own time range
```

### Problem Analysis

#### Issue #1: Sparklines do NOT share the same timespan

Both sparklines compute `effectiveStart` independently using identical logic (copy-paste):

**BodyweightSparkline** (lines 31-46):
```dart
final calculatedStart = switch (timeRange) {
  TimeRange.oneMonth => now.subtract(const Duration(days: 30)),
  TimeRange.sixMonths => now.subtract(const Duration(days: 180)),
  TimeRange.allTime => DateTime(2000, 1, 1),
};
final earliestData = DateTime.parse(sorted.first.loggedAt);
final effectiveStart = earliestData.isAfter(calculatedStart) ? earliestData : calculatedStart;
```

**CaloriesSparkline** (lines 27-44):
```dart
// Identical logic, but uses sorted.first.date instead of sorted.first.loggedAt
```

Because each dataset has different earliest data points, `effectiveStart` differs between sparklines. The `maxDays` for the X-axis is also computed independently per sparkline.

#### Issue #2: Data-range fallback not implemented

The current "smart range adjustment" only does:
```dart
effectiveStart = max(calculatedStart, earliestData)
```

This means if data spans only 5 days but the user selected "1M" (30 days), the graph still shows 30 days with 25 days of empty space. The issue requests that when `latestData - earliestData < requestedRange`, the graph should use the actual data range instead.

Additionally, the two sparklines need to agree on which dataset's range to use. The issue says: "the longer of the two Sparklines" determines the final range.

#### Issue #3: Today not included in calorie sparkline

**Root cause:** `historicalCaloriesProvider` (`food_log_provider.dart:52-53`):
```dart
final now = DateTime.now();
final thirtyDaysAgo = now.subtract(const Duration(days: 30));
final entries = await logService.getEntriesForDateRange(thirtyDaysAgo, now);
```

The `getEntriesForDateRange` method (`database.dart:165-174`) uses `isBetweenValues(startStr, endStr)` where `endStr` is today's date string like `"2026-05-18"`. Food entries logged today have timestamps like `"2026-05-18T14:30:00"`. The string comparison `"2026-05-18T14:30:00" >= "2026-05-18"` is `true`, so today IS included.

However, the provider hard-codes a 30-day window. For "6M" and "All" toggles, this is a bug — the calorie sparkline can never show more than 30 days of data regardless of the toggle selection.

#### Issue #4: Single-point same-day extension not implemented

When both sparklines have a single point on the same day, the range should extend back 1 day. Currently there is no logic for this edge case.

### Dead Code

`lib/providers/historical_calories_provider.dart` exists as a standalone file with an identical `historicalCaloriesProvider` definition. It is NOT imported anywhere — `dashboard_screen.dart` imports from `food_log_provider.dart` instead. This file should be deleted.

### Required Changes

| Change | File(s) | Detail |
|--------|---------|--------|
| Create shared range computation | New: `lib/providers/shared_dashboard_range_provider.dart` | Provider that watches bodyweight + calorie data + time range, computes `(start, end, maxDays)` tuple used by both sparklines |
| Fix calorie data window | `lib/providers/food_log_provider.dart` | Remove hard-coded 30-day window from `historicalCaloriesProvider`; accept a date range parameter or create a new provider that fetches all dates |
| Refactor BodyweightSparkline | `lib/features/dashboard/widgets/bodyweight_sparkline.dart` | Accept `effectiveStart`, `effectiveEnd`, `maxDays` as constructor params instead of computing internally |
| Refactor CaloriesSparkline | `lib/features/dashboard/widgets/calories_sparkline.dart` | Same as above |
| Update DashboardScreen | `lib/features/dashboard/dashboard_screen.dart` | Compute shared range, pass to both sparklines, fetch calorie data for correct range |
| Delete dead code | `lib/providers/historical_calories_provider.dart` | Remove unused file |
| Update tests | `test/features/dashboard/widgets/calories_sparkline_test.dart` | Tests at lines 98-119 ("filters to last 30 days only") will need updating since filtering moves to the provider level |

---

## 2. OpenFoodFacts API (Issues #5-7)

### Current Architecture

**Files:**
- `lib/core/api/open_food_facts_client.dart` (100 lines) — HTTP client with retry logic
- `lib/providers/food_search_provider.dart` (143 lines) — `FoodSearchService` wrapper
- `lib/features/logging/widgets/food_search_delegate.dart` (448 lines) — search UI

### Problem Analysis

#### Issue #5: Intermittent "no results" from successful API calls

**Current behavior** (`open_food_facts_client.dart:21-73`):
- Retry loop handles: HTTP 429, 5xx, SocketException, HttpException, TimeoutException (up to 3 attempts with 500ms * attempt backoff)
- FormatException: no retry, returns `[]`
- HTTP 200 with empty `products` array: returns `[]` immediately — **no retry**

The issue describes "successful but returns no results" — this is the `products: []` case. The API returns HTTP 200 with an empty products list. This could be:
1. A genuine empty result (product doesn't exist)
2. A transient OFF issue (server returned empty but should have results)

**Current UI behavior** (`food_search_delegate.dart:420-425`):
```dart
if (items.isEmpty) {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: Text('No results found'),
  );
}
```
Static text — no retry option.

**Proposed approach:**
- In `OpenFoodFactsClient.search()`: after successful parse with empty products, retry up to 2 times with exponential backoff (1s, 2s)
- In `_WebSearchContent`: replace static "No results found" with tappable "No results — tap to retry" (consistent with the existing "Search failed. Tap to retry." pattern at lines 410-417)

#### Issue #6: Failed API calls should silently retry

**Current behavior** (`food_search_provider.dart:102-112`):
```dart
Future<WebSearchResult> searchWeb(String query) async {
  if (query.trim().isEmpty) return WebSearchSuccess([]);
  try {
    final results = await apiClient.search(query);
    return WebSearchSuccess(results.map(...).toList());
  } catch (_) {
    return WebSearchFailure();
  }
}
```

The client already retries internally (up to 3 attempts). Only after exhausting retries does it return `[]`, which becomes `WebSearchSuccess([])` — not a failure. The `WebSearchFailure` path is only hit if an unexpected exception escapes the client's try-catch (unlikely given the exhaustive exception handling).

**Conclusion:** The "search failed" message is probably never shown in practice because the client catches everything and returns `[]`. If we add empty-result retries in the client, the failure path becomes even less likely. The "No results found" message should get a retry tap handler as a safety net.

#### Issue #7: Search trigger behavior

**Current debounce** (`food_search_delegate.dart:354-386`):
```dart
Timer? _debounceTimer;
String _debouncedQuery = '';

void _startDebounce() {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 400), () {
    if (mounted) setState(() => _debouncedQuery = widget.query);
  });
}
```

- 400ms debounce on query changes — **already implemented**
- Timer starts in `initState()` and restarts in `didUpdateWidget` when query changes

**Problem A: Search on focus with non-empty query**
When the search delegate opens, `buildSuggestions` is called immediately. If `query` is non-empty (from a previous search session), the debounce timer starts and will trigger a search after 400ms. The issue says "shouldn't immediately trigger an API call when the search bar receives focus, only on edit."

**Fix:** Add a `_hasUserEdited` flag. Only start debounce when the query actually changes from its initial value (or from empty). On first mount, if query is non-empty, set `_debouncedQuery = ''` and only update when the user types.

**Problem B: Duplicate search on Enter during in-flight request**
When the user presses Enter, `buildResults` is called, which creates a new `_FoodSearchContent` → new `_WebSearchContent` → new FutureBuilder. If a previous search is still in-flight, this creates a duplicate request. The `ValueKey('$_debouncedQuery-$_retryTrigger')` on the FutureBuilder means a new key is created for each build, so the old FutureBuilder is disposed and a new one starts.

**Fix:** Add a `_isSearching` boolean in `_WebSearchContentState`. Set to `true` when FutureBuilder starts, `false` when complete. In `didUpdateWidget`, if `_isSearching` is true, don't restart the debounce.

**Problem C: Toggle from "My Foods" to "Search the Web" should trigger search**
Currently, toggling modes just switches the content widget. If there's a non-empty query, the web search shows "Enter a search term" (because `_debouncedQuery` is empty until the debounce fires). The issue says we SHOULD launch a search if the search bar is non-empty AND the user toggles to "Search the Web."

**Fix:** In `_FoodSearchContentState`'s `onSelectionChanged` handler, when switching to 'web' and `widget.query.isNotEmpty`, pass the query directly to `_WebSearchContent` as an "immediate query" parameter that bypasses debounce.

### Required Changes

| Change | File(s) | Detail |
|--------|---------|--------|
| Add empty-result retry | `lib/core/api/open_food_facts_client.dart` | In `search()`, after successful parse with empty products, retry up to 2 times with 1s, 2s backoff |
| Add retry tap to "No results" | `lib/features/logging/widgets/food_search_delegate.dart` | Replace static text with `GestureDetector` + `_retryTrigger` increment (same pattern as failure retry at lines 410-417) |
| Prevent focus-triggered search | `lib/features/logging/widgets/food_search_delegate.dart` | Add `_queryInitialized` flag; only start debounce when user actually edits |
| Prevent duplicate Enter searches | `lib/features/logging/widgets/food_search_delegate.dart` | Add `_isSearching` guard in `_WebSearchContentState` |
| Trigger search on mode toggle | `lib/features/logging/widgets/food_search_delegate.dart` | Pass `immediateQuery` to `_WebSearchContent` when toggling to web with non-empty query |
| Update tests | `test/api/open_food_facts_client_test.dart` | Add test for empty-result retry |
| Update tests | `test/features/logging/search_delegate_test.dart` | Update toggle test to account for new behavior |

---

## 3. Food Search UX (Issues #8-9)

### Issue #8: Backing out of custom food creation

**Current navigation flow** (`combined_log_screen.dart:56-78`):
```
CombinedLogScreen
  └── showSearch(FoodSearchDelegate)
        └── "Create custom food" tapped
              ├── onCreateCustomFood() → sets _pendingCreateCustom = true
              └── Navigator.pop(null) → pops the search delegate
  └── result is null, _pendingCreateCustom is true
        └── _openCreateCustom() → pushes ManualFoodForm
              └── User backs out → returns to CombinedLogScreen (skips search)
```

The search delegate is popped BEFORE `ManualFoodForm` is pushed. If the user backs out of the form, they return to the log screen, not the search.

**Proposed fix:** Push `ManualFoodForm` ON TOP of the search delegate instead of popping first.

```
CombinedLogScreen
  └── showSearch(FoodSearchDelegate)
        └── "Create custom food" tapped
              └── Navigator.push(ManualFoodForm) — stacked on top of delegate
                    └── User saves → pop form, then pop delegate, then quick-log
                    └── User backs out → pop form, return to search delegate
```

This requires changing `onCreateCustomFood` from a `VoidCallback` that sets a flag to a callback that receives the `BuildContext` and pushes the form directly.

**Recipe form path** (`recipe_form_screen.dart:66-94`): Same pattern — `_pendingCreateCustom` flag, pops delegate, then pushes form. Same fix applies.

### Issue #9: Redundant delete button on food items

**Current UI** (`food_search_delegate.dart:278-330`):
```dart
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(icon: Icons.edit, ...),     // Edit button — KEEP
    IconButton(icon: Icons.delete_outline, ...),  // Delete button — REMOVE
  ],
),
```

Long-press delete already works (lines 258-277):
```dart
onLongPress: () async {
  if (onDeleteFood != null && item.localId != null) {
    final food = Food(...);
    await onDeleteFood!(food);
  }
},
```

**Fix:** Remove the delete `IconButton` (lines 305-328). Keep the edit button. Keep the long-press handler. The `onDeleteFood` callback remains wired for long-press use.

### Required Changes

| Change | File(s) | Detail |
|--------|---------|--------|
| Fix custom food navigation | `lib/features/logging/widgets/food_search_delegate.dart` | Change `onCreateCustomFood` to accept `BuildContext`; push `ManualFoodForm` on top of delegate |
| Fix custom food navigation | `lib/features/logging/combined_log_screen.dart` | Update `onCreateCustomFood` callback to push form with context |
| Fix custom food navigation | `lib/features/recipes/recipe_form_screen.dart` | Same pattern update |
| Remove food delete button | `lib/features/logging/widgets/food_search_delegate.dart` | Remove lines 305-328 (delete IconButton) |
| Update tests | `test/features/logging/search_delegate_test.dart` | May need updates if navigation flow changes |

---

## 4. Recipe Management (Issue #10)

### Issue #10: Redundant delete button on recipe cards

**Current UI** (`recipe_list_screen.dart:176-190`):
```dart
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(icon: Icons.edit, ...),      // Edit button — KEEP
    IconButton(icon: Icons.delete_outline, ...),  // Delete button — REMOVE
  ],
),
```

Long-press delete already works with haptic feedback and scale animation (lines 192-199):
```dart
onLongPress: () async {
  setState(() => _isLongPressing = true);
  await HapticFeedback.mediumImpact();
  if (mounted) {
    setState(() => _isLongPressing = false);
    widget.onDelete();
  }
},
```

Tooltip at line 161 already says: `'Tap to log, long-press to delete'`.

**Fix:** Remove the delete `IconButton` (lines 184-188). Keep the edit button. Keep the long-press handler.

### Required Changes

| Change | File(s) | Detail |
|--------|---------|--------|
| Remove recipe delete button | `lib/features/recipes/recipe_list_screen.dart` | Remove lines 184-188 (delete IconButton from trailing Row) |

---

## 5. Macro Settings — Protein Basis Toggle (Issue #11)

### Current Architecture

**Files:**
- `lib/core/database/tables/user_goals.dart` — `proteinGPerLb` column (line 7)
- `lib/providers/unit_preferences_provider.dart` — `UnitPreferences` class with protein conversion helpers
- `lib/providers/macro_targets_provider.dart` — `MacroTargets.compute` uses `weightLb * proteinGPerLb`
- `lib/features/onboarding/onboarding_screen.dart` — protein slider (lines 484-502)
- `lib/features/goals/goals_screen.dart` — protein slider (lines 462-480)

### Current Protein Calculation

```dart
// macro_targets_provider.dart:62-64
final proteinGPerLb = goals?.proteinGPerLb ?? 1.0;
final weightLb = weightKg != null ? weightKg * 2.20462 : 0.0;
final proteinGrams = weightLb * proteinGPerLb;
```

Protein is always computed as: **bodyweight in pounds × g/lb ratio**.

The slider range is 0.5–2.0 (stored as g/lb), displayed as:
- Imperial: `0.5–2.0 g/lb`
- Metric: `1.1–4.4 g/kg` (converted via `× 2.20462`)

Recommended range displayed: `0.8–1.4 g/lb` or `1.8–3.1 g/kg`.

### Issue Requirement

Add a toggle between:
1. **Per lb bodyweight** (current behavior): `proteinGrams = weightLb × value`
2. **Per cm height**: `proteinGrams = heightCm × value`

The issue notes: "these should use the same ranges (0.8-1.4 g/cm recommended, total range should still be available)." This means the slider stays 0.5–2.0 but the unit label changes from `g/lb`/`g/kg` to `g/cm`.

### Required Changes

#### Database (`lib/core/database/tables/user_goals.dart`)

Add a new column:
```dart
TextColumn get proteinBasis => text().withDefault(const Constant('bodyweight'))();
```

Values: `'bodyweight'` or `'height'`. Default is `'bodyweight'` for backward compatibility. No migration needed (schema v1, app not published).

#### UnitPreferences (`lib/providers/unit_preferences_provider.dart`)

Add helper for height-based protein unit:
```dart
String proteinUnitForBasis(String basis) {
  if (basis == 'height') return 'g/cm';
  return useImperial ? 'g/lb' : 'g/kg';
}
```

The slider range (0.5–2.0) stays the same regardless of basis — only the label changes.

#### Onboarding Screen (`lib/features/onboarding/onboarding_screen.dart`)

Add state variable and toggle:
```dart
String _proteinBasis = 'bodyweight';
```

Add a `SegmentedButton<String>` above the protein slider:
```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'bodyweight', label: Text('Per lb bodyweight')),
    ButtonSegment(value: 'height', label: Text('Per cm height')),
  ],
  selected: {_proteinBasis},
  onSelectionChanged: (v) => setState(() => _proteinBasis = v.first),
),
```

Update slider label to use `_unitPrefs.proteinUnitForBasis(_proteinBasis)`.
Update recommended range text based on basis.
Save `proteinBasis` in `_save()` via `UserGoalsCompanion`.

#### Goals Screen (`lib/features/goals/goals_screen.dart`)

Add identical toggle with perfect UI parity:
```dart
String _proteinBasis = 'bodyweight';
```

Load from DB in `_loadGoals()`: `_proteinBasis = goals.proteinBasis;`
Save in `_save()`: `proteinBasis: Value(_proteinBasis)`

#### MacroTargets (`lib/providers/macro_targets_provider.dart`)

Update `MacroTargets.compute` to accept `proteinBasis`:
```dart
final proteinBasis = goals?.proteinBasis ?? 'bodyweight';
final proteinValue = goals?.proteinGPerLb ?? 1.0;

double proteinGrams;
if (proteinBasis == 'height') {
  final heightCm = goals?.heightCm ?? 0.0;
  proteinGrams = heightCm * proteinValue;
} else {
  final weightLb = weightKg != null ? weightKg * 2.20462 : 0.0;
  proteinGrams = weightLb * proteinValue;
}
```

**Edge case:** If `heightCm` is null (user hasn't set height), fall back to bodyweight-based calculation or use 0.

#### Tests

| Test File | Changes Needed |
|-----------|---------------|
| `test/providers/macro_targets_provider_test.dart` | Add tests for height-based protein calculation; update `UserGoal` factory to include `proteinBasis` |
| `test/features/goals/goals_screen_test.dart` | Update seed goals to include `proteinBasis`; add test for toggle persistence |
| `test/features/dashboard/dashboard_screen_test.dart` | Update `makeGoals()` helper to include `proteinBasis` |

### UI Parity Checklist

Both onboarding and goals screens must have:
- [ ] Same `SegmentedButton` segments and labels
- [ ] Same slider range (0.5–2.0)
- [ ] Same label format: `"Protein: X.X <unit>"`
- [ ] Same recommended range text (updates based on basis)
- [ ] Same recommended range values: `0.8–1.4` for bodyweight (g/lb or g/kg), `0.8–1.4` for height (g/cm)

---

## Implementation Dependency Graph

```
Phase 3 (Food UX) ────────────────────────────────────────────────┐
Phase 4 (Recipe UX) ──────────────────────────────────────────────┤  Can run in parallel
Phase 2 (OFF API) ────────────────────────────────────────────────┤
Phase 1 (Sparklines) ─────────────────────────────────────────────┤
Phase 5 (Protein) ────────────────────────────────────────────────┘

Phase 3 depends on: nothing
Phase 4 depends on: nothing
Phase 2 depends on: nothing
Phase 1 depends on: nothing
Phase 5 depends on: nothing (DB column has default value)

All phases are independent and can be implemented in parallel.
```

## Test Impact Summary

| Phase | Test Files Affected | Nature of Changes |
|-------|-------------------|-------------------|
| Sparklines | `calories_sparkline_test.dart`, `dashboard_screen_test.dart` | Update time range tests; add tests for shared range, single-point extension, today inclusion |
| OFF API | `open_food_facts_client_test.dart`, `search_delegate_test.dart` | Add empty-result retry test; update toggle/debounce tests |
| Food UX | `search_delegate_test.dart` | Update navigation flow tests; delete button tests may need removal |
| Recipe UX | `recipes_test.dart` | Minor — delete button removal |
| Protein | `macro_targets_provider_test.dart`, `goals_screen_test.dart`, `dashboard_screen_test.dart` | Add height-based protein tests; update UserGoal factories |

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Sparkline shared range logic is complex with edge cases (empty datasets, single points, same-day) | High | Write comprehensive unit tests for the range computation function before UI integration |
| Protein basis changes interpretation of existing `proteinGPerLb` column | Medium | Default `'bodyweight'` ensures existing data works unchanged; only new users who explicitly toggle see different behavior |
| OFF API retry for empty results could hit rate limits | Medium | Use conservative backoff (1s, 2s) and limit to 2 retries; respect 429 responses |
| Custom food navigation change affects both log screen and recipe form paths | Medium | Test both paths thoroughly; the flag-based approach in recipe form is slightly different |
