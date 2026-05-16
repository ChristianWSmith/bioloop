# BioLoop Development Checklist

Track progress on issues from `issues.txt`. See individual tickets in `tickets/` for detailed implementation plans.

---

## Tickets

### Ticket 1: Fix Maintenance Progress Bar Count
**Priority:** High | **Complexity:** Low | **File:** `tickets/001-fix-maintenance-progress-bar.md`

- [ ] Modify `_countDataDaysProvider` to count food days only
- [ ] Remove weight date collection logic
- [ ] Test with multi-day food logs
- [ ] Run `flutter analyze > analyze.log 2>&1` — zero issues
- [ ] Run `flutter test > test.log 2>&1` — all tests pass

**Status:** ⬜ Not Started

---

### Ticket 2: Unified Recipe Management Interactions
**Priority:** High | **Complexity:** Low-Medium | **File:** `tickets/002-unified-recipe-management.md`

- [ ] Remove `pickerMode` parameter from `RecipeListScreen`
- [ ] Simplify `_openRecipe()` to always log
- [ ] Add edit button to `_RecipeCard` trailing actions
- [ ] Update tooltips and interactions
- [ ] Update `CombinedLogScreen._onLogRecipe()` call
- [ ] Test tap, long-press, edit, delete flows
- [ ] Run `flutter analyze > analyze.log 2>&1` — zero issues
- [ ] Run `flutter test > test.log 2>&1` — all tests pass

**Status:** ⬜ Not Started

---

### Ticket 3: Add Accent Color Preference to Database
**Priority:** Medium | **Complexity:** Low | **File:** `tickets/003-add-accent-color-db.md`

- [ ] Add `accentColorSeed` column to `UserGoals` table
- [ ] Run `dart run build_runner build`
- [ ] Verify generated code compiles
- [ ] Run `flutter analyze > analyze.log 2>&1` — zero issues
- [ ] Run `flutter test > test.log 2>&1` — all tests pass

**Status:** ⬜ Not Started

---

### Ticket 4: Dynamic Theme System
**Priority:** Medium | **Complexity:** Medium | **File:** `tickets/004-dynamic-theme-system.md`

- [ ] Update `AppTheme.light()` to accept optional seed color
- [ ] Update `AppTheme.dark()` to accept optional seed color
- [ ] Wire up `userGoalsProvider` in `app.dart`
- [ ] Convert `accentColorSeed` int to `Color` object
- [ ] Test theme reactivity
- [ ] Run `flutter analyze > analyze.log 2>&1` — zero issues
- [ ] Run `flutter test > test.log 2>&1` — all tests pass

**Status:** ⬜ Not Started

---

### Ticket 5: Accent Color Picker in Settings
**Priority:** Medium | **Complexity:** Medium | **File:** `tickets/005-accent-color-picker.md`

- [ ] Add color palette constant
- [ ] Add "Accent Color" ListTile to Settings
- [ ] Implement color picker dialog
- [ ] Save selected color to database
- [ ] Invalidate `userGoalsProvider` after save
- [ ] Test color persistence across restarts
- [ ] Run `flutter analyze > analyze.log 2>&1` — zero issues
- [ ] Run `flutter test > test.log 2>&1` — all tests pass

**Status:** ⬜ Not Started

---

## Execution Order

```
Ticket 1 → Ticket 2 → Ticket 3 → Ticket 4 → Ticket 5
     │           │           └─────┬─────┘
     │           │                 │
     └───────────┴─────────────────┘
          Independent         Dependent chain
```

**Recommended sequence:**
1. **Ticket 1** — Quick win, isolated change
2. **Ticket 2** — Independent, improves core UX
3. **Ticket 3** — Database schema (prerequisite for 4 & 5)
4. **Ticket 4** — Theme system (requires 3)
5. **Ticket 5** — Color picker UI (requires 3 & 4)

---

## Reference

- **Issues:** `issues.txt`
- **Discovery:** `DISCOVERY.md`
- **Architecture:** `AGENTS.md`

---

## Notes

- All `flutter analyze` and `flutter test` commands should redirect to log files
- Read log files after running commands (do not pipe/grep directly)
- Commit after each ticket completion
- Test manually after each ticket before moving to next
