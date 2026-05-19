# Implementation Checklist

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 1 | [Display brand in food search results](tickets/001-display-brand-in-search.md) | ⬜ Not started |
| 2 | [Add editable brand field to ManualFoodForm](tickets/002-editable-brand-field.md) | ⬜ Not started |
| 3 | [Reorder "My Foods" — imported > logged > alphabetical](tickets/003-reorder-my-foods.md) | ⬜ Not started |
| 4 | [Web search tap → open form instead of immediate log](tickets/004-web-tap-opens-form.md) | ⬜ Not started |
| 5 | [End-to-end verification and regression](tickets/005-regression-verification.md) | ⬜ Not started |

## Dependencies

```
Ticket 1 ─┐
           ├── (independent, can run in parallel)
Ticket 2 ─┘
           │
Ticket 3 ──┤ (independent of 1, 2, 4)
           │
Ticket 4 ──┤ (depends on Ticket 2's ManualFoodForm id > 0 fix)
           │
Ticket 5 ──┘ (depends on all above)
```

## Recommended Order

1. **Ticket 3** — Sorting algorithm (backend only, no UI risk)
2. **Ticket 1** — Brand display (additive UI change)
3. **Ticket 2** — Brand editable form (additive form change)
4. **Ticket 4** — Web tap flow (depends on Ticket 2's `id > 0` fix in ManualFoodForm)
5. **Ticket 5** — Regression verification (runs after all above)

## Related Documents

- [Discovery document](DISCOVERY.md) — Full analysis, architecture, and implementation plans
- [Issues](issues.txt) — Original issue descriptions
