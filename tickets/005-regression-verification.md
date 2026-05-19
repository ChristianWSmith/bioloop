# Ticket 5: End-to-end verification and regression

## Status
- [ ] Not started

## Scope
Full test suite + manual verification

## Context
After implementing Tickets 1–4, run the full test suite and perform manual regression testing to ensure no existing functionality was broken.

## Acceptance Criteria
- [ ] `flutter analyze` passes with zero issues
- [ ] `flutter test` passes with zero failures
- [ ] All existing tests continue to pass (no test regressions)

## Manual Verification Checklist
- [ ] **Brand display**: Food with brand shows brand in search results
- [ ] **Brand edit**: Create custom food with brand, verify it saves and displays
- [ ] **Sorting**: Import OFF food → appears at top of "My Foods"; log it → moves to logged section
- [ ] **Web tap flow**: Tap web result → form opens → save → food appears in "My Foods"
- [ ] **Barcode scanner**: Scan barcode → food still logs immediately (unchanged)
- [ ] **Recipe form search**: Search for food in recipe form → tap still returns item (unchanged)
- [ ] **Edit existing food**: Edit a food → brand field pre-fills and saves correctly
- [ ] **Delete food**: Long-press delete still works and removes food from list
- [ ] **Quick log from "My Foods"**: Tap local food → QuickFoodLogSheet still opens and logs
- [ ] **Calorie clamping**: OFF imports still clamp calories to macro max

## Notes
- This ticket has no code changes — it is verification only
- If any test fails or manual check reveals a bug, create a follow-up ticket
- Run `flutter analyze > analyze.log 2>&1` and read the log file
- Run `flutter test > test.log 2>&1` and read the log file
