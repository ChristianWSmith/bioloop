# TICKET-003: Redesign food entry display — macro bars, calories on right, improved section headers

**Priority:** Medium (visual polish)
**Files:**
- `lib/features/logging/combined_log_screen.dart`
- (Optionally) `lib/features/logging/widgets/macro_bars.dart`
**Estimate:** ~2h

---

## Context

The log screen's food entry list currently shows a dense line of text with calories, macros (P/C/F), and log time, plus a colored meal-type badge on the trailing edge. Three issues drive a redesign:

1. **Issue 3** — The macro text and time are hard to parse visually. Replace with 3 proportional colored bars (protein=blue, carbs=green, fat=orange) showing each macro's calorie contribution as a fraction of the food's total calories.
2. **Issue 5** — The meal-type badges are redundant with the section headers. Remove them. Show calories on the trailing edge instead.
3. **Issue 5** — Section headers (Breakfast/Lunch/Dinner/Snack) need to "pop" more. Add a colored left border strip matching the meal type color.

### Macro breakdown bar formula

For a food with P protein grams, C carbs grams, F fat grams:
- Total calories = P×4 + C×4 + F×9
- Protein bar width = (P×4) / total
- Carbs bar width = (C×4) / total
- Fat bar width = (F×9) / total
- Uses `Expanded(flex: (proteinCals).toInt(), ...)` for proportional sizing
- Empty/zero-total case: render nothing

### Meal type colors (from existing `_mealTypeBadge`)

| Meal | Color |
|------|-------|
| breakfast | `Colors.orange` |
| lunch | `Colors.blue` |
| dinner | `Colors.purple` |
| snack | `Colors.teal` |

---

## Acceptance criteria

1. **Macro breakdown bars**: each food entry shows 3 colored bars in a `Row` below the food name. Protein=blue, Carbs=green, Fat=orange. Widths are exactly proportional to each macro's calorie contribution. Bars fill the full available width, wrapped in `ClipRRect` for rounded corners.
2. **No macro text or time**: the subtitle no longer shows `"350 cal  •  P30g  C40g  F10g  •  14:30"`. The macro bars are the only subtitle element.
3. **Calories on the right**: each entry's `trailing` shows `"350 cal"` in a bold, readable style, replacing the meal-type badge.
4. **Section headers pop**: each meal section header (Breakfast/Lunch/Dinner/Snack) has a 3px colored left border matching its meal type color. Optionally includes the meal type icon (from `MealTypeSelector`: `Icons.free_breakfast`, etc.).
5. **No regressions**: swipe-to-delete, tap-to-edit, meal-type section grouping, and the overall layout remain functional.

---

## Implementation plan

### A. Create `_MacroBreakdownBar` widget

Add to `combined_log_screen.dart` (or extract to `macro_bars.dart` if reusable):

```dart
class _MacroBreakdownBar extends StatelessWidget {
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  // Colors used: Colors.blue, Colors.green, Colors.orange

  Widget build(BuildContext context) {
    final proteinCals = proteinGrams * 4;
    final carbsCals = carbsGrams * 4;
    final fatCals = fatGrams * 9;
    final total = proteinCals + carbsCals + fatCals;

    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            Expanded(
              flex: (proteinCals).toInt().clamp(1, 9999),
              child: Container(color: Colors.blue),
            ),
            Expanded(
              flex: (carbsCals).toInt().clamp(1, 9999),
              child: Container(color: Colors.green),
            ),
            Expanded(
              flex: (fatCals).toInt().clamp(1, 9999),
              child: Container(color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
```

Edge case: if any macro is 0 (or very small), `flex: 0` would collapse the segment. Use `.clamp(1, 9999)` to guarantee visibility for non-zero contributions.

### B. Replace subtitle in ListTile

```dart
// Before:
subtitle: Text(
  '${entry.calories.toInt()} cal  •  '
  'P${entry.proteinGrams.toStringAsFixed(0)}g  '
  'C${entry.carbsGrams.toStringAsFixed(0)}g  '
  'F${entry.fatGrams.toStringAsFixed(0)}g'
  '${_timeFromLoggedAt(entry.loggedAt) != null ? "  •  ${_timeFromLoggedAt(entry.loggedAt)}" : ""}',
),
// After:
subtitle: Padding(
  padding: const EdgeInsets.only(top: 4),
  child: _MacroBreakdownBar(
    proteinGrams: entry.proteinGrams,
    carbsGrams: entry.carbsGrams,
    fatGrams: entry.fatGrams,
  ),
),
```

### C. Replace trailing

```dart
// Before:
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _mealTypeBadge(entry.mealType),
  ],
),
// After:
trailing: Text(
  '${entry.calories.toInt()} cal',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontWeight: FontWeight.w600,
  ),
),
```

### D. Remove `_mealTypeBadge` method (optional — it's only used in that one place)

Delete lines 160–182 from `combined_log_screen.dart`.

### E. Improve section headers

```dart
// Replace the section header Row (lines 321–341) with:
Container(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
  child: Row(
    children: [
      Icon(_mealIcons[mealType] ?? Icons.circle, size: 18,
           color: _mealColors[mealType] ?? Colors.grey),
      const SizedBox(width: 8),
      Text(
        mealType[0].toUpperCase() + mealType.substring(1),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: _mealColors[mealType] ?? Colors.grey,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          color: (_mealColors[mealType] ?? Colors.grey).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          '${groups[mealType]!.length}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _mealColors[mealType] ?? Colors.grey,
          ),
        ),
      ),
    ],
  ),
),
```

Add a `_mealColors` map and `_mealIcons` map at the class level (or extract from `_mealTypeBadge`/`MealTypeSelector`).

---

## Testing

### Manual verification

1. Open log screen with food entries logged for today
2. Verify each entry shows:
   - Food name as title
   - 3 colored bars below (blue/green/orange) proportional to macro calorie split
   - `"XXX cal"` on the right side
   - No macro text, no time, no meal-type badge
3. Verify section headers show:
   - Colored left border strip matching meal type
   - Icon next to meal name
   - Entry count badge is more visible
4. Log a food with only one macro (e.g., pure protein) — verify the bar is all one color
5. Log a food with 0 calories — verify no bar is shown (handled by `SizedBox.shrink()`)

### Regression verification

- Run `flutter test > test.log 2>&1` — all existing tests must pass
- Run `flutter analyze > analyze.log 2>&1` — zero issues
- Swipe-to-delete must still work
- Tap entry must still open `EditEntrySheet`
