# Progress Checklist

## Dashboard Sparklines (Tickets 01-04)

- [ ] **Ticket 01** — Fix calorie data provider to support arbitrary date ranges
- [ ] **Ticket 02** — Create shared dashboard range provider
- [ ] **Ticket 03** — Refactor sparklines to accept range parameters
- [ ] **Ticket 04** — Add sparkline edge cases (single-point extension, today inclusion)

## OpenFoodFacts API (Tickets 05-07)

- [ ] **Ticket 05** — Add empty-result retry to OpenFoodFactsClient
- [ ] **Ticket 06** — Add retry tap to "No results found" in web search
- [ ] **Ticket 07** — Fix search trigger behavior (focus, Enter, toggle)

## Food Search UX (Tickets 08-09)

- [ ] **Ticket 08** — Fix custom food creation navigation
- [ ] **Ticket 09** — Remove redundant delete button from food items

## Recipe Management (Ticket 10)

- [ ] **Ticket 10** — Remove redundant delete button from recipe cards

## Macro Settings (Tickets 11-13)

- [ ] **Ticket 11** — Add proteinBasis column and UnitPreferences helpers
- [ ] **Ticket 12** — Add protein basis toggle to onboarding screen
- [ ] **Ticket 13** — Add protein basis toggle to goals screen + update MacroTargets

---

## Dependency Graph

```
T01 → T02 → T03 → T04

T05 → T06

T07 (independent)

T08 (independent)

T09 (independent)

T10 (independent)

T11 → T12 → T13
```

## Parallel Execution Groups

| Group | Tickets | Notes |
|-------|---------|-------|
| A | T01 | Foundation for sparkline work |
| B | T05, T07, T08, T09, T10 | All independent — can run simultaneously |
| C | T02, T03, T04 | Sequential — each depends on previous |
| D | T06 | Can run after T05, or in parallel with Group B |
| E | T11 | Foundation for protein work |
| F | T12 | Depends on T11 |
| G | T13 | Depends on T11, T12 |

**Maximum parallelism:** 5 tickets at once (T05, T07, T08, T09, T10 in Group B).

---

## Summary

| Category | Tickets | Status |
|----------|---------|--------|
| Dashboard Sparklines | 01, 02, 03, 04 | 0/4 complete |
| OpenFoodFacts API | 05, 06, 07 | 0/3 complete |
| Food Search UX | 08, 09 | 0/2 complete |
| Recipe Management | 10 | 0/1 complete |
| Macro Settings | 11, 12, 13 | 0/3 complete |
| **Total** | **13** | **0/13 complete** |
