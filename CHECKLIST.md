# Work Checklist

## Tickets

| # | Ticket | Status | Notes |
|---|--------|--------|-------|
| 1 | [Remove duplicate recipe button](tickets/001-remove-duplicate-recipe-button.md) | ⬜ Pending | Trivial — delete AppBar actions block |
| 2 | [Clamp OFF calorie values](tickets/002-clamp-off-calories.md) | ⬜ Pending | New utility + two call sites |
| 3 | [Fix stale food list after delete](tickets/003-fix-stale-food-list.md) | ⬜ Pending | New provider + convert to ConsumerWidget |
| 4 | [Maintenance diagnostics](tickets/004-maintenance-diagnostics.md) | ⬜ Pending | Largest — algorithm + provider + UI + tests |

## Execution Order

```
1 → 2 → 3 → 4
```

Tickets 1-3 are independent. Ticket 4 is the largest and should be done last.

## Pre-Implementation Baseline

- [x] All 242 tests pass
- [x] `flutter analyze` — 1 pre-existing info issue (`use_build_context_synchronously` in settings_screen.dart)
- [x] Discovery documented in `DISCOVERY.md`

## Post-Implementation Verification (run after all tickets)

- [ ] `flutter analyze` passes with zero new issues
- [ ] `flutter test` passes (all tests)
- [ ] `AGENTS.md` updated with any new conventions or architecture changes
