# Implementation Checklist

Tickets are ordered by dependency and grouped for efficiency.

| # | Ticket | Status | Notes |
|---|--------|--------|-------|
| T1 | Fix "Create custom food" ordering | Pending | Independent, trivial |
| T2 | Make auto-calc always overwrite calories | Pending | Independent, trivial |
| T3 | Make recent foods refresh reactively | Pending | Independent, trivial |
| T4 | Show quantity/unit on history tab entries | Pending | Independent, trivial |
| T5 | Extract shared serving helper + fix ingredient display | Pending | Independent, ~15 min |
| T6 | Add recipe editing | Pending | Touches same widget as T7 |
| T7 | Add recipe duplication | Pending | Pair with T6 (recommend `PopupMenuButton`) |

## Recommended execution order

1. **T1** — trivial, zero risk
2. **T2** — trivial, zero risk
3. **T3** — trivial, zero risk
4. **T4** — trivial, zero risk
5. **T5** — requires a `dart run build_runner build` if tests depend on imports (no drift changes, so build_runner likely not needed)
6. **T6 + T7** — batch together, they share the `_RecipeCard` trailing widget; implement `PopupMenuButton` once with Edit, Duplicate, Delete options

## Per-ticket validation

After each ticket:
- Run `flutter analyze > analyze.log 2>&1` — must have zero issues
- Run `flutter test > test.log 2>&1` — all existing tests must pass
- Run the app and manually verify the changed behaviour

## Before merging batch

- [ ] `flutter analyze` passes with zero issues
- [ ] `flutter test` passes all tests
- [ ] Manual smoke test of affected screens
