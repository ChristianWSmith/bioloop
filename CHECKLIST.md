# Implementation Progress Checklist

## Phase 1 — Independent Quick Wins

| # | Ticket | Issues | Status | Notes |
|---|--------|--------|--------|-------|
| 01 | Quick UI paper cuts | #14, #8 | ✅ Complete | Imperial default + remove delete from today's entries |
| 02 | Add brand field to foods table | #11 | ✅ Complete | Schema v4, migration, model propagation |
| 03 | Auto-recalculate calories on macro edit | #7 | ✅ Complete | Remove `_caloriesManuallyEdited` flag |
| 04 | Forward-fill bodyweight for missing days | #13 | ✅ Complete | Algorithm change in maintenance calculator |
| 05 | Polish recipe UX | #2, #4, #5 | ✅ Complete | Ingredient display, edit icon, duplicate recipe |

## Phase 2 — Search Infrastructure

| # | Ticket | Issues | Status | Notes |
|---|--------|--------|--------|-------|
| 06 | Restrict edit entry to quantity only | #12 | ✅ Complete | Read-only macros in EditEntrySheet |
| 07 | Rework food search with My Foods / Search Web toggle | #10, #1, #6, #9 | ✅ Complete | New DAO, split service, redesigned delegate, deleted recent_foods_provider |

## Phase 3 — Screen Consolidation

| # | Ticket | Issues | Status | Dependencies |
|---|--------|--------|--------|-------------|
| 08 | Merge Log and History tabs | #15, #3 | ❌ Pending | #06, #07 |

## Dependencies

```
Phase 1 (Tickets 01-05) — any order, no dependencies
        │
Phase 2 (Tickets 06-07) — any order, no dependencies between them
        │
        ↓
Phase 3 (Ticket 08)     — requires 06 + 07
```

## Legend

- ❌ Pending
- 🔄 In Progress
- ✅ Complete
- ⏸ Blocked
