# TKT-2: Format bodyweight delete confirmation timestamp

**Risk**: Low | **Files**: 1 | **Est**: <15min

---

## Context

The bodyweight deletion confirmation dialog at `bodyweight_screen.dart:134-135` uses the raw `entry.loggedAt` string directly:

```dart
content: Text(
    'Delete weight $displayWeight ${prefs.weightUnit} from ${entry.loggedAt}?'),
```

The list display (lines 102-104) parses the same field via `DateTime.parse()` and reformats it as `YYYY-MM-DD`:

```dart
final date = DateTime.parse(entry.loggedAt);
final dateStr =
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
```

While both currently produce `YYYY-MM-DD` (since `AddWeightSheet` stores dates in that format), the dialog bypasses the formatting logic used by the list tile. If the storage format ever changes, they'd diverge.

## Acceptance Criteria

- The delete confirmation dialog shows the date formatted the same way as the list entry subtitle
- The raw `loggedAt` string is never shown to the user
- The formatting is consistent between the list display and the dialog

## Implementation

Replace the raw `entry.loggedAt` in the dialog content text with the formatted date. Optionally extract a shared helper:

```dart
// Before (line 134-135):
'Delete weight $displayWeight ${prefs.weightUnit} from ${entry.loggedAt}?'

// After:
final date = DateTime.parse(entry.loggedAt);
final dateStr =
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
// ...
'Delete weight $displayWeight ${prefs.weightUnit} from $dateStr?'
```

A `_formatDate(String loggedAt)` helper could be extracted to share between `_buildEntry` (line 102-104) and `_confirmDelete` (line 126), but an inline duplicate is acceptable given the small scope.

## Testing

- **No test changes needed** — this is a UI text change. No behavior is modified.
- Verify manually: long-press a bodyweight entry, confirm the dialog shows `YYYY-MM-DD` (same as list subtitle).
- After implementation, run `flutter analyze` to confirm zero issues.
