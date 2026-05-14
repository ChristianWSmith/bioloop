# T2: Robust OpenFoodFacts serving-size parser

## Context & Discovery

OpenFoodFacts returns `serving_size` as a free-form string with wildly inconsistent formats. The current parser (`_parseServingInfo` in `food_result.dart:95–119`) handles common patterns but fails on multi-word units, plural unit names, non-gram parenthetical units, and leading text.

**Format examples from `issues.txt`:**
```
"0.25 cup (45g)"      "100g"              "1 portion (45g)"
"1 portion (15 ml)"   "15 ml"             "14 crackers (30 g)"
"100.0g"              "4.7 g (1 SLICE)"
```

**Current parser gaps** (from DISCOVERY.md §2):
- `"100 grams"` — captures unit as `grams` instead of normalizing to `g`
- `"1 cup (8oz)"` — gramEquivalent = 8 instead of converting oz→g (~227g)
- `"1 portion (15 ml)"` — gramEquivalent = 15 (wrong — volume, not mass)
- `"15 ml"` — returns null → defaults to `servingQuantity=1, servingUnit='serving'`
- `"8 fl oz (240g)"` — captures `fl` as unit, loses `oz`
- `"about 1 cup (240g)"` — leading text causes regex `^` anchor to fail

**Pipeline insertion point:** The parser is called from `FoodResult.fromJson()` at `food_result.dart:51`. The return type is `({double quantity, String unit, double? gramEquivalent})?`. Changes are isolated to this single function.

**Test gap:** No dedicated unit tests for `_parseServingInfo()`. Only 3 indirect test cases in `test/api/open_food_facts_client_test.dart`.

## Intent

Replace `_parseServingInfo()` with a robust parser that:
- Handles all observed OFF serving-size formats
- Prefers grams as the default unit when a gram equivalent is available
- Normalizes units (`grams` → `g`, `gram` → `g`)
- Converts common non-gram weight units to grams (oz × 28.35)
- Preserves volume units as-is (ml, L — don't guess mass)
- Always returns a best-effort parsed result (never null)

## Acceptance Criteria

1. All 8+ serving-size formats from `issues.txt` parse correctly
2. Gram equivalent is extracted from parenthetical expressions
3. Unit normalization: `"grams"` → `"g"`, `"gram"` → `"g"`, `"ml"` stays `"ml"`
4. Weight conversion: `oz` → grams with ×28.35 factor
5. Volume units (ml, L) are preserved as quantity with their original unit
6. Food with only per-100g nutriments (Path B in `fromJson`) still hardcodes `servingQuantity=100, servingUnit='g'`
7. `_parseServingInfo` never returns null for any input
8. `flutter analyze` passes with zero issues
9. All existing tests pass
10. New comprehensive unit tests cover all known OFF formats

## Files to modify

| File | Change |
|------|--------|
| `lib/core/api/models/food_result.dart` | Rewrite `_parseServingInfo()` (lines 95–119); update callers if return type changes |
| `test/api/serving_size_parser_test.dart` | **New file** — comprehensive unit tests |

### New parser behavior

Replace the regex-only approach with a stepwise parser:

1. **Normalize input** — trim, collapse whitespace, lowercase
2. **Extract parenthetical grams** — `(\d+(?:\.\d+)?)\s*g` → if found, use as gram weight
3. **Extract quantity and unit** from main text:
   - If parenthetical has grams and main text has `qty + unit`: use both, prefer gram-based serving
   - If parenthetical has volume (ml, L): use original unit, don't convert
   - If no parenthetical: extract any numeric quantity + rest as unit
4. **Convert weight units** — if unit is `oz`, multiply quantity by 28.35 and switch to `g`
5. **Normalize unit** — `grams`/`gram` → `g`
6. **Fallback** — if nothing parseable, return `(quantity: 1, unit: 'serving', gramEquivalent: null)` but also attempt to extract any numeric value from the string

### Key design constraint

The parser should prefer `g` as the serving unit whenever possible. For a food like `"1 cup (240g)"`, the output should be `(quantity: 240, unit: 'g')` — not `(quantity: 1, unit: 'cup')`. This matches the preference stated in `issues.txt`: "we should PREFER ingesting the data as one of the default units in the app."

However, `servingSizeGrams` is being removed (T1). The parser's output record should similarly drop `gramEquivalent`:

```dart
// New return type (no gramEquivalent since the column is gone)
({double quantity, String unit}) _parseServingInfo(String label);
```

The parser normalizes directly: when grams are found, `(quantity: grams, unit: 'g')`.

## Testing

### Unit tests for the parser (new file: `test/api/serving_size_parser_test.dart`)

All examples from `issues.txt`:
- `"0.25 cup (45g)"` → `(45, 'g')`
- `"100g"` → `(100, 'g')`
- `"1 portion (45g)"` → `(45, 'g')`
- `"1 portion (15 ml)"` → `(15, 'ml')` (volume preserved)
- `"15 ml"` → `(15, 'ml')`
- `"14 crackers (30 g)"` → `(30, 'g')`
- `"100.0g"` → `(100, 'g')`
- `"4.7 g (1 SLICE)"` → `(4.7, 'g')`

Additional edge cases:
- `"100 grams"` → `(100, 'g')`
- `"1 cup (8oz)"` → `(227, 'g')` (8 × 28.35)
- `"8 fl oz (240g)"` → `(240, 'g')` (parenthetical grams preferred)
- `"about 1 cup (240g)"` → `(240, 'g')`
- `"1 L (1000ml)"` → `(1000, 'ml')`
- `"1 serving"` → `(1, 'serving')`
- `"2 slices"` → `(2, 'slices')`
- `""` → `(1, 'serving')` (empty string fallback)
- `null` → `(1, 'serving')` (null input fallback — caller handles)

### Integration
- `flutter test > test.log 2>&1` — all existing + new tests pass
- `flutter analyze > analyze.log 2>&1` — zero issues
