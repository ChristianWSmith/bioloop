# Ticket 1: Add Red Over-Target Coloring to MacroBars Widget

**Issue:** #1 — Macro bars should turn red when exceeded  
**Status:** Pending  
**Priority:** High (quick win)  
**Estimated effort:** 30 minutes  
**Dependencies:** None

---

## Context

The `MacroBars` widget at the top of the log screen shows 4 progress bars (calories, protein, carbs, fat). Currently, bars maintain their original color even when the user exceeds their target. The `MacroRing` widget on the dashboard already implements this feature correctly — it turns red when over target. This ticket brings parity between the two components.

**User impact:** Visual feedback mismatch — dashboard rings turn red when over, but log screen bars don't, causing confusion.

---

## Current State

**File:** `lib/features/logging/widgets/macro_bars.dart`

```dart
class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: color.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation(color), // ← Always uses original color
        minHeight: 8,
      ),
    );
  }
}
```

**Comparison:** `MacroRing` already has `isOver` logic (line 27):
```dart
final isOver = target > 0 && consumed > target;
```

And uses red when over (line 138):
```dart
final fillColor = isOver ? Colors.red : color;
```

---

## Requirements

### Functional
- [ ] Calories bar turns red when `consumedCalories > targetCalories`
- [ ] Protein bar turns red when `consumedProtein > proteinGrams`
- [ ] Carbs bar turns red when `consumedCarbs > carbsGrams`
- [ ] Fat bar turns red when `consumedFat > fatGrams`
- [ ] Each bar changes color independently (one can be red while others are normal)

### Visual
- [ ] Red color matches `MacroRing` implementation (`Colors.red`)
- [ ] Bar fill still clamps to 100% visually (no overflow beyond bar bounds)
- [ ] Works correctly in both light and dark themes

### Edge cases
- [ ] Handle `target = 0` gracefully (should not crash, though this shouldn't happen in practice)
- [ ] Handle negative consumed values (should not crash)

---

## Implementation Plan

1. Add `isOver` boolean parameter to `_ProgressBar` widget
2. Modify `_MacroRow` and `_MacroColumn` to calculate and pass `isOver`
3. Update `_ProgressBar.build()` to use conditional color:
   ```dart
   final barColor = isOver && value > 1.0 ? Colors.red : color;
   ```
4. Test all 4 bars independently

**Lines to change:** ~20 lines in `macro_bars.dart`

---

## Testing

### Manual testing
1. Log food until calories exceed target → verify calories bar turns red
2. Log high-protein food until protein exceeds target → verify protein bar turns red (calories may still be normal)
3. Repeat for carbs and fat
4. Verify all 4 bars can be red simultaneously
5. Test in dark mode

### Widget tests (optional, can be added later)
Create `test/features/logging/widgets/macro_bars_test.dart`:
```dart
testWidgets('calories bar turns red when exceeded', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MacroBars(
          targets: MacroTargets(..., targetCalories: 2000, ...),
          consumedCalories: 2200, // Over
          consumedProtein: 50,
          consumedCarbs: 50,
          consumedFat: 50,
        ),
      ),
    ),
  );
  // Assert calories bar uses red color
});
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/features/logging/widgets/macro_bars.dart` | Add `isOver` parameter to `_ProgressBar`, calculate in `_MacroRow` and `_MacroColumn` |

---

## Definition of Done

- [ ] All 4 bars turn red independently when exceeded
- [ ] Red color matches dashboard rings
- [ ] No console errors in debug mode
- [ ] Tested in light and dark themes
- [ ] `flutter analyze` passes with zero issues
- [ ] Manual testing completed

---

## References

- `lib/features/dashboard/widgets/macro_ring.dart:27` — `isOver` calculation example
- `lib/features/dashboard/widgets/macro_ring.dart:138` — red color usage
- `lib/features/logging/combined_log_screen.dart:326-332` — MacroBars call site
