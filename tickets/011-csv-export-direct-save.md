# 011 — Improve CSV export to allow saving directly to device

- **Phase**: 3 — Bug Fixes
- **Priority**: Low

## Overview

Currently CSV export uses `Share.shareXFiles()` which opens the system share sheet. On Android, the share sheet surfaces social apps, messaging, and email — but not a "Save to Files" / "Save to Downloads" option. Users should be able to save the CSV file directly to their device storage.

## Context from Discovery

- `shareCsv()` (`lib/features/history/export.dart:35–42`): writes CSV to `getTemporaryDirectory()`, then calls `Share.shareXFiles([XFile(file.path)])`.
- `share_plus ^10.1.4` handles the Android `FileProvider` internally — no native config needed for the share sheet to access temp files.
- The issue is that the share sheet doesn't offer a "Save to device" option. The MIME type of the file may influence available targets — CSV files might not be recognized as savable.

## Options

1. **Use `Share.shareXFiles` with MIME type hint**: Set `text/csv` MIME type on `XFile`. Some share sheet implementations respect this and offer file-save targets.
2. **Write to `getApplicationDocumentsDirectory()` instead of temp**: The system `Files` app might pick up files from the app's documents directory.
3. **Use a different package**: `open_file` or `open_filex` to open the CSV with a file viewer that also offers save.
4. **Use `share_plus` platform-specific methods**: On Android, use `SharePlusAndroid.shareFiles` with appropriate params.
5. **Save directly to Downloads**: Use `getExternalStorageDirectory()` (or SAF on newer Android) to write the file to a user-accessible location, then optionally share it.

## Recommended Approach

Investigate whether setting the MIME type to `text/csv` on `XFile` improves share sheet behavior. If not, implement a direct save-to-downloads option using `getApplicationDocumentsDirectory()` and then use `open_filex` to open it so the user can then save from the viewer. Or add a "Save to device" button that copies from temp to a persistent location.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/history/export.dart` | Add MIME type to `XFile`. Optionally add a direct-save function using `path_provider` to write to a persistent external location. |
| `pubspec.yaml` | May need additional dependency (`open_filex` or similar) |

## Acceptance Criteria

- [ ] CSV export offers an option to save directly to the device (not just share)
- [ ] Saved file is accessible via the device's Files app or Downloads
- [ ] Existing share functionality continues to work
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Unit test: CSV content generation unchanged
- Manual test (Android): verify file can be saved to Downloads and opened
