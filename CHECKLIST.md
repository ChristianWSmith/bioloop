# Implementation Checklist

**Project:** bioloop — Issues #1-5 Resolution  
**Created:** May 16, 2026  
**Last Updated:** May 16, 2026

---

## Ticket Status Overview

| Ticket | Priority | Status | Assignee | Effort |
|--------|----------|--------|----------|--------|
| [#1: Recipe macros zeroes](tickets/001-bug-recipe-macros-zeroes.md) | 🔴 Critical | ⬜ Pending | Unassigned | 2-3h |
| [#2: Maintenance pre-weight assumption](tickets/002-feature-maintenance-preweight-assumption.md) | 🟡 High | ⬜ Pending | Unassigned | 4-6h |
| [#3: Unit filtering](tickets/003-ux-filter-units-openfoodfacts.md) | 🟢 Medium | ⬜ Pending | Unassigned | 3-4h |
| [#4: Recipe discoverability](tickets/004-ux-recipe-discoverability.md) | 🟢 Low-Medium | ⬜ Pending | Unassigned | 2-3h |
| [#5: Documentation update](tickets/005-docs-update-agents.md) | 🟢 Low | ⬜ Pending | Unassigned | 1-2h |

**Total Estimated Effort:** 12-18 hours (1.5-2.5 days)

---

## Sprint Plan

### Sprint 1: Bug Fixes (1-2 days)

#### Ticket #1: Recipe macros zeroes
- [ ] **Code:** Implement ingredient re-insert in `recipe_form_screen.dart:204-217`
- [ ] **Tests:** Add unit test: edit → save → verify ingredients persist
- [ ] **Tests:** Add unit test: edit → save → verify macros correct
- [ ] **Manual:** Test edit flow with 3+ ingredients
- [ ] **Manual:** Test log edited recipe → verify macros not zero
- [ ] **QA:** Run `flutter test test/features/recipes/` — all pass
- [ ] **QA:** Run `flutter analyze` — zero issues
- [ ] **Status:** ⬜ Not Started ⟳ In Progress ✅ Complete

---

#### Ticket #2: Maintenance pre-weight assumption
- [ ] **Code:** Modify `maintenance_calculator.dart:57-78` — initialize `lastKnownWeight` to oldest weight
- [ ] **Docs:** Add algorithm documentation comment (forward-fill behavior)
- [ ] **Tests:** Add test: single weight entry → all 30 days use that weight
- [ ] **Tests:** Add test: delete oldest weight → assumption shifts
- [ ] **Tests:** Add test: mid-window start → prior dates use oldest weight
- [ ] **Tests:** Add test: no weights → returns null (regression)
- [ ] **Manual:** Test onboarding scenario (1 weight)
- [ ] **Manual:** Test sparse early data (weights days 20-30)
- [ ] **Manual:** Test delete oldest weight → estimate updates
- [ ] **QA:** Run `flutter test test/core/algorithms/` — all pass
- [ ] **QA:** Run `flutter analyze` — zero issues
- [ ] **Status:** ⬜ Not Started ⟳ In Progress ✅ Complete

---

### Sprint 2: UX Improvements (1-2 days)

#### Ticket #3: Unit filtering
- [ ] **Code:** Add `source` parameter to `ServingSizePicker`
- [ ] **Code:** Add `_allowedUnits` computed property (filtered vs. full)
- [ ] **Code:** Update dropdown items to use `_allowedUnits`
- [ ] **Code:** Pass `food.source` from `QuickFoodLogSheet`
- [ ] **Tests:** Add test: imported food shows filtered dropdown
- [ ] **Tests:** Add test: manual food shows all units
- [ ] **Tests:** Add test: custom unit selection works
- [ ] **Tests:** Add test: null source defaults to all units
- [ ] **Manual:** Test OpenFoodFacts import → filtered dropdown
- [ ] **Manual:** Test manual food → all units shown
- [ ] **Manual:** Test barcode scan → filtered dropdown
- [ ] **QA:** Run `flutter test test/features/logging/` — all pass
- [ ] **QA:** Run `flutter analyze` — zero issues
- [ ] **Status:** ⬜ Not Started ⟳ In Progress ✅ Complete

---

#### Ticket #4: Recipe discoverability
- [ ] **Code:** Convert `_RecipeCard` to StatefulWidget
- [ ] **Code:** Add `Tooltip` wrapper with mode-specific messages
- [ ] **Code:** Add haptic feedback on long-press
- [ ] **Code:** Add visual feedback (scale animation + color change)
- [ ] **Tests:** Add test: long-press triggers delete dialog
- [ ] **Tests:** Add test: long-press in picker mode does nothing
- [ ] **Tests:** Add test: tooltip shows correct message
- [ ] **Manual:** Test long-press with haptic feedback
- [ ] **Manual:** Test visual feedback (scale/color)
- [ ] **Manual:** Test picker mode unchanged
- [ ] **Manual:** Test accessibility (screen reader)
- [ ] **QA:** Run `flutter test test/features/recipes/` — all pass
- [ ] **QA:** Run `flutter analyze` — zero issues
- [ ] **Status:** ⬜ Not Started ⟳ In Progress ✅ Complete

---

### Sprint 3: Documentation (0.5 days)

#### Ticket #5: Documentation update
- [ ] **Docs:** Add recipe management modes subsection
- [ ] **Docs:** Add recipe edit bug fix note
- [ ] **Docs:** Add maintenance forward-fill note
- [ ] **Docs:** Add unit filtering subsection
- [ ] **Verify:** Check all file paths exist
- [ ] **Verify:** Check all line numbers (±5 accuracy)
- [ ] **QA:** Run `flutter analyze` — zero issues (docs only)
- [ ] **Status:** ⬜ Not Started ⟳ In Progress ✅ Complete

---

## Testing Summary

### Test Files to Create/Modify

| File | Action | Tickets |
|------|--------|---------|
| `test/features/recipes/recipes_test.dart` | Modify (add 2-3 tests) | #1, #4 |
| `test/core/algorithms/maintenance_calculator_test.dart` | Modify (add 4 tests) | #2 |
| `test/features/logging/widgets/serving_size_picker_test.dart` | Create (4 tests) | #3 |

### Test Commands

```bash
# After Ticket #1
flutter test test/features/recipes/recipes_test.dart > test.log 2>&1

# After Ticket #2
flutter test test/core/algorithms/maintenance_calculator_test.dart > test.log 2>&1

# After Ticket #3
flutter test test/features/logging/widgets/serving_size_picker_test.dart > test.log 2>&1

# After Ticket #4
flutter test test/features/recipes/recipes_test.dart > test.log 2>&1

# Final verification (all tests)
flutter test > test.log 2>&1

# Lint verification
flutter analyze > analyze.log 2>&1
```

---

## Manual Testing Scenarios

### Recipe Flow (Tickets #1, #4)
- [ ] Create recipe with 3 ingredients → save → macros correct
- [ ] Edit recipe → change ingredient quantity → save → macros updated
- [ ] Edit recipe → remove ingredient → save → ingredient gone
- [ ] Log edited recipe → entry has correct macros (not zero)
- [ ] Long-press recipe → haptic feedback → delete dialog
- [ ] Tap recipe in picker mode → log sheet (no edit)

### Maintenance Flow (Ticket #2)
- [ ] New user, 1 weight → maintenance estimate appears (may be null)
- [ ] User with weights days 20-30 → estimate appears
- [ ] Delete oldest weight → estimate updates
- [ ] Existing user (30+ weights) → estimate unchanged

### Unit Flow (Ticket #3)
- [ ] Import "oats" from OpenFoodFacts → dropdown shows `['g', 'Custom…']`
- [ ] Create manual food → dropdown shows all 11 units
- [ ] Select custom unit → log entry → entry shows custom unit
- [ ] Barcode scan → same filtered behavior as import

---

## Definition of Done (Project-Wide)

- [ ] All 5 tickets complete
- [ ] All tests passing (`flutter test` — zero failures)
- [ ] Lint passing (`flutter analyze` — zero issues)
- [ ] Manual testing complete (all scenarios above)
- [ ] AGENTS.md updated with all changes
- [ ] DISCOVERY.md referenced in commit messages
- [ ] No console errors in debug mode
- [ ] Performance verified (< 100ms for maintenance calculation)

---

## Risk Log

| Risk | Likelihood | Impact | Mitigation | Status |
|------|------------|--------|------------|--------|
| Existing users' maintenance estimates change | Low | Medium | Only affects users with < 7 weights (likely none) | ⚪ Monitored |
| Recipe edit introduces new bug | Low | High | Comprehensive test coverage | ⚪ Monitored |
| Unit filtering breaks manual foods | Low | Medium | Backward compatible (null source = all units) | ⚪ Monitored |
| Haptic feedback crashes on some devices | Low | Low | Platform check, silent no-op on unsupported | ⚪ Monitored |

---

## Notes

**Ticket Dependencies:**
- Ticket #5 depends on #1-4 (documenting implemented behavior)
- Tickets #1-4 can be done in parallel (no dependencies)

**Recommended Order:**
1. Ticket #1 (critical bug fix)
2. Ticket #2 (algorithm improvement)
3. Ticket #3 (UX improvement)
4. Ticket #4 (UX improvement)
5. Ticket #5 (documentation)

**Branch Strategy:**
- Create feature branch per ticket (e.g., `fix/recipe-macros-zeroes`)
- Or single branch for all (e.g., `feat/issues-1-5-resolution`)
- Merge to main after all tickets complete

**Commit Messages:**
- Reference ticket number: `fix: recipe macros zero after edit (#1)`
- Reference discovery: `feat: maintenance pre-weight assumption (#2, DISCOVERY.md)`

---

## Progress Log

### May 16, 2026
- [x] Discovery work complete (DISCOVERY.md created)
- [x] Ticket plan created (5 tickets)
- [x] Tickets documented in `tickets/` directory
- [x] CHECKLIST.md created
- [ ] Ticket #1 implementation started
- [ ] Ticket #2 implementation started
- [ ] Ticket #3 implementation started
- [ ] Ticket #4 implementation started
- [ ] Ticket #5 implementation started

---

**Next Steps:**
1. Begin Ticket #1 (critical bug fix)
2. Update this checklist as progress is made
3. Commit after each ticket complete
4. Run full test suite before merging
