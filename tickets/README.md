# bioloop — Ticket tracker

This directory contains tickets for the issue discovery work documented in `DISCOVERY.md`.

## Ticket summary

| # | Ticket | Issues | Status |
|---|--------|--------|--------|
| 1 | Fix dashboard refresh after goals save | #4, #5 | Open |
| 2 | Remove meal templates feature | #6, #8 | Open |
| 3 | Fix serving/portion macro math | #1, #3 | Open |
| 5 | Auto-calculate calories from macros in manual food form | — | Open |

## No-action issues

| Issue | Reason |
|-------|--------|
| #2 | Recipe add ingredient recent foods — already works (`FoodSearchDelegate` + `_RecentFoodsSection` used in both log screen and recipe form) |
| #7 | Recent foods clickable — already works (`_RecentFoodsSection` wraps `onTap: () => onSelectItem(item.food)`) |

## Execution order

T1 is independent and can be done any time. T2 must be done before T3 (both modify `log_food_screen.dart`; T2 deletes code T3 would otherwise need to fix). T3 is the most impactful and should get the most review attention. T5 is independent and touches only `manual_food_form.dart`.
