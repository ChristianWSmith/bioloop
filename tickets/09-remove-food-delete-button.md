# Ticket 09: Remove redundant delete button from food items

**Category:** Food Search UX
**Status:** Pending
**Depends on:** None
**Blocks:** None

## Problem

Food items in "My Foods" mode have both a delete button (trailing `IconButton`) AND long-press delete functionality. The delete button is redundant since users can already delete by long-pressing.

## Context

- `lib/features/logging/widgets/food_search_delegate.dart:278-330` — trailing `Row` with edit + delete buttons
- `lib/features/logging/widgets/food_search_delegate.dart:305-328` — the delete `IconButton` to remove
- `lib/features/logging/widgets/food_search_delegate.dart:258-277` — long-press handler that calls `onDeleteFood` (keep this)
- `lib/features/logging/combined_log_screen.dart:68-69` — `onDeleteFood` callback wiring (still needed for long-press)

## Changes Required

Remove the delete `IconButton` from the trailing `Row` in `_LocalSearchContent._buildList()`:

```dart
// Before (lines 278-330):
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(icon: Icons.edit, ...),
    IconButton(icon: Icons.delete_outline, ...),  // REMOVE THIS
  ],
),

// After:
trailing: IconButton(
  icon: const Icon(Icons.edit, size: 20),
  onPressed: () { ... },
  tooltip: 'Edit food',
),
```

Keep:
- The edit `IconButton`
- The `onLongPress` handler (calls `onDeleteFood`)
- The `onDeleteFood` callback parameter (still used by long-press)

## Acceptance Criteria

- [ ] Food items show only the edit button in the trailing area
- [ ] Long-press on a food item still triggers the delete confirmation dialog
- [ ] The `onDeleteFood` callback is still wired and functional (used by long-press)
- [ ] `flutter analyze` passes with zero issues

## Testing

- Widget test: food item has edit button but no delete button in trailing area
- Widget test: long-press on food item → delete confirmation dialog appears
- Existing deletion refresh test in `search_delegate_test.dart` should still pass (uses long-press)

## Files Affected

- `lib/features/logging/widgets/food_search_delegate.dart` — remove delete IconButton from trailing Row
