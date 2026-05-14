# Ticket Checklist

| # | Ticket | Status | Notes |
|---|--------|--------|-------|
| T1 | Remove vestigial `servingSizeGrams` column | Done | Column removed, schema v3, all files cleaned, 236 tests pass |
| T2 | Robust OpenFoodFacts serving-size parser | Done | Stepwise parser, 16 test cases, 254 tests pass |
| T3 | Honor imperial/metric in all displayed values | Done | UnitPreferences gains 8 helpers; protein slider, rate display, height fields, CSV export all adapt; 255 tests pass |
| T4 | Fix stale maintenance estimate refresh chain | Done | `dataTriggerProvider` incremented at all 10 mutation sites; `maintenanceProvider` and `_countDataDaysProvider` watch it; both now reactive; 255 tests pass |
| T5 | Quick-log from recent foods + duplicate entries | Done | Trailing "+" icon on recent foods opens `QuickFoodLogSheet`; duplicate icon on today's entries pre-fills sheet; both auto-save + invalidate providers; 255 tests pass |

## Legend

- **Pending** — Not started
- **In Progress** — Currently being worked
- **Review** — Implementation done, needs review/testing
- **Done** — Merged, analyze + tests pass
