# Implementation Checklist

Track progress on the 7 tickets from `tickets/`.

| # | Ticket | Description | Status |
|---|--------|-------------|--------|
| 1 | [001-fix-create-custom-food-button.md](tickets/001-fix-create-custom-food-button.md) | Fix "Create custom food" button not opening the form | ☐ |
| 2 | [002-fix-recipe-ingredient-default-quantity.md](tickets/002-fix-recipe-ingredient-default-quantity.md) | Fix recipe ingredient quantity defaulting to 1 | ☐ |
| 3 | [003-fix-edit-entry-serving-label.md](tickets/003-fix-edit-entry-serving-label.md) | Fix edit entry quantity hint showing "100 g" instead of just "g" | ☐ |
| 4 | [004-fix-goals-propagation-to-macro-targets.md](tickets/004-fix-goals-propagation-to-macro-targets.md) | Fix protein/fat goal updates not propagating to macro targets | ☐ |
| 5 | [005-fix-onboarding-back-out.md](tickets/005-fix-onboarding-back-out.md) | Fix onboarding discard confirms leaving a black screen | ☐ |
| 6 | [006-fix-web-search-enter-key-reset.md](tickets/006-fix-web-search-enter-key-reset.md) | Fix Enter key on web search resetting to "My Foods" | ☐ |
| 7 | [007-fix-date-switcher-centering.md](tickets/007-fix-date-switcher-centering.md) | Fix date switcher "Today" text not screen-centered | ☐ |

## Progress

- **Completed:** 0 / 7
- **Remaining:** 7

## Verification steps for all tickets

After each ticket, run:

```bash
flutter analyze > analyze.log 2>&1
flutter test > test.log 2>&1
```
