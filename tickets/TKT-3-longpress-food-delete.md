# TKT-3: Long press to delete food entries

**Risk**: Low | **Files**: 1 | **Est**: <15min

---

## Context

Food entries in the log screen can currently be deleted only via swipe-to-dismiss (`Dismissible` widget at `combined_log_screen.dart:362`). There is no long-press gesture on the entry `ListTile`.

The `_deleteEntry()` method already exists (lines 115-159) and handles: confirmation dialog → DB delete → `dataTriggerProvider` increment → error dialog. The bodyweight screen (`bodyweight_screen.dart:111`) already demonstrates the exact pattern to follow: `onLongPress: () => _confirmDelete(context, ref, entry)`.

## Acceptance Criteria

- Long-pressing a food entry in the log tab shows the delete confirmation dialog
- After confirming, the entry is deleted and the list refreshes
- Swipe-to-dismiss still works as before
- Both paths use the same `_deleteEntry()` helper

## Implementation

**File**: `lib/features/logging/combined_log_screen.dart:412`

Add `onLongPress` to the `ListTile` inside the `Dismissible`:

```dart
// Before:
onTap: () => _editEntry(entry),

// After:
onTap: () => _editEntry(entry),
onLongPress: () => _deleteEntry(entry),
```

The `_deleteEntry(entry)` method at line 115 already handles confirmation and error cases, so no new logic is needed.

## Testing

- **No test changes needed** — this adds a new gesture path to existing functionality. The existing swipe-to-dismiss test (in `search_delegate_test.dart` or widget test) should continue to pass.
- Verify manually: long-press a food entry → confirmation dialog → Cancel (no-op) → long-press again → Delete (removes entry).
- After implementation, run `flutter analyze` to confirm zero issues.
