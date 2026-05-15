# BioLoop — Implementation Checklist

Use this to track progress on the active ticket set.

---

## Ticket 001 — Onboarding defaults

- [x] `_sex` initialized to `'male'` instead of `null`
- [x] `emptySelectionAllowed` removed from sex `SegmentedButton`
- [x] `_goalType` default changed from `'cut'` to `'maintain'`
- [x] Calorie adjustment default changed from `'-500'` to `'0'`
- [x] `flutter analyze` passes with zero issues (pre-existing dead_code warning in database.dart only)

---

## Ticket 002 — Exclude today from maintenance

- [x] `DateTime.now()` changed to `DateTime.now().subtract(const Duration(days: 1))` in `maintenance_provider.dart`
- [x] All existing maintenance calculator tests pass
- [x] `flutter analyze` passes with zero issues

---

## Ticket 003 — Compact macro bars

- [x] `lib/features/logging/widgets/macro_bars.dart` created
- [x] `MacroBars` widget displays full-width calories bar
- [x] Protein, Carbs, Fat shown as 1/3-width bars below
- [x] Widget added to `CombinedLogScreen`'s ListView above meal groups
- [x] `macroTargetsProvider` watched for target values
- [x] Values update reactively on entry add/edit/delete
- [x] Works for both today and past dates
- [x] `flutter analyze` passes with zero issues

---

## Ticket 004 — Log screen AppBar cleanup

### #6 — Center DayNavigator
- [x] `centerTitle: true` added to log screen `AppBar`
- [x] Date indicator visually centered in AppBar

### #10 — Remove relog button
- [x] `Icons.replay` `IconButton` removed from food entry trailing widgets
- [x] `_onDuplicate` method removed

### #11 — Log recipe as own button
- [x] `Icons.menu_book` `IconButton` added to AppBar `actions`
- [x] "Log recipe" `PopupMenuItem` removed from overflow menu
- [x] Overflow menu (with share/save items) still functional

### Combined
- [x] `flutter analyze` passes with zero issues

---

## Ticket 005 — Barcode scanning button

- [x] Barcode scan `IconButton` added to `FoodSearchDelegate.buildActions()`
- [x] `OpenFoodFactsClient` accessible in the delegate
- [x] Tapping button opens `BarcodeScannerScreen`
- [x] Found food → quick-log sheet opens → search closes
- [x] Not found → "Enter manually" or "Scan again" options work
- [x] Cancel → returns to search delegate
- [x] `flutter analyze` passes with zero issues

---

## Ticket 006 — Search screen UX fixes

### #9 — Re-log returns to log screen
- [ ] Quick-log via `+` icon closes search delegate after sheet closes
- [ ] Tap-to-select path still works correctly

### #5 — Toggle off-center (investigate)
- [ ] Root cause identified and reproduced
- [ ] SegmentedButton stays centered in both modes

### #8 — Web search toggle flip (investigate)
- [ ] Root cause identified and reproduced
- [ ] Web search errors no longer reset toggle to "My Foods"

### Combined
- [ ] `flutter analyze` passes with zero issues

---

## Final verification

- [ ] `flutter analyze` passes with zero issues
- [ ] `flutter test` passes (run via `flutter test > test.log 2>&1`)
- [ ] `flutter run` starts without crashes
