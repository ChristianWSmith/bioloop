# bioloop — AGENTS.md

Standard Flutter app (default `flutter create` template). Minimal custom code.

## Commands

| Action | Command |
|--------|---------|
| Get dependencies | `flutter pub get` |
| Analyze (lint) | `flutter analyze` |
| Run tests | `flutter test` |
| Run app | `flutter run` |

## Structure

- `lib/main.dart` — single app entrypoint
- `test/widget_test.dart` — default Flutter smoke test; update or remove as feature tests are added per ticket
- No CI, no custom build tooling, no assets
- Default `flutter_lints` lint rules via `analysis_options.yaml`

## App State

| Ticket | Status | Date | Agent |
|--------|--------|------|-------|
| T0 — Initial scaffold | ✅ Complete | — | Manual |
| T1 — Drift schema & migrations | ✅ Complete | 2026-05-12 | AI |
| T2 — App shell + navigation + theme | ✅ Complete | 2026-05-12 | AI |
| T2b — Onboarding flow | ✅ Complete | 2026-05-12 | AI |
| T3 — OpenFoodFacts API client | ✅ Complete | 2026-05-12 | AI |
| T4 — Foods reference table + local search | ✅ Complete | 2026-05-12 | AI |
| T5 — Manual food creation form | ✅ Complete | 2026-05-12 | AI |
| T6 — Log food screen | ✅ Complete | 2026-05-12 | AI |
| T7 — Bodyweight logging | ✅ Complete | 2026-05-12 | AI |
| T8 — Food history screen | ✅ Complete | 2026-05-12 | AI |
| T9 — Goals screen | ✅ Complete | 2026-05-12 | AI |
| T10 — Macro targets provider | ✅ Complete | 2026-05-12 | AI |
| T11 — Dashboard: summary + progress rings | ✅ Complete | 2026-05-12 | AI |
| T12 — Bodyweight chart | ✅ Complete | 2026-05-12 | AI |
| T13 — Maintenance calculator algorithm | ✅ Complete | 2026-05-12 | AI |
| T14 — Dashboard: full integration | ✅ Complete | 2026-05-12 | AI |

After completing each ticket, the agent working on it appends a new row here. This table
is the single source of truth for what has been built.

## Ticket Workflow

When starting work, follow these steps in order:

### 1. Identify the next ticket
- Open `TICKET_CHECKLIST.md`, find the first unchecked ticket whose dependencies are met.
- Dependencies are satisfied when the tickets listed as prerequisites in the ticket's spec are marked complete.
- Confirm with the human before starting implementation.

### 2. Read all relevant context
- Read the ticket file in `tickets/<NN>-<name>.md`.
- Read the relevant sections of `PLAN.md` — schema DDL, architecture tree, feature phases, design rules.
- Read the existing source files you'll be modifying or adjacent to.
- Understand conventions by reading neighboring files (provider patterns, widget structure, DAO style).

### 3. Implement the ticket
- Follow Flutter / drift / Riverpod conventions already established in the codebase.
- Every drift table file lives in `lib/core/database/tables/`.
- Every Riverpod provider lives in `lib/features/<feature>/providers/` (or `lib/core/providers/` for shared ones).
- Every screen/widget lives in `lib/features/<feature>/`.
- Write tests alongside features in `test/` (see existing `widget_test.dart` for setup patterns).
- Never commit unless explicitly asked.

### 4. Verify with automated checks
- Run `flutter analyze` — fix all issues.
- Run `flutter test` — all tests must pass.
- If new tests were written, confirm they pass.

### 5. Human verification
- The ticket spec includes a "Human verification" or acceptance-criteria section.
- Walk through each item with the human. Do not mark the ticket done until the human confirms each step passes.

### 6. Update tracking files
- **TICKET_CHECKLIST.md**: mark the ticket as `[x]`.
- **AGENTS.md App State table**: append a new row with the ticket number, ✅ status, today's date, and agent name (or "Manual" if the human drove).

### 7. Propagate downstream changes
- If implementation revealed something that changes a downstream ticket's plan (e.g., a different column name, a new provider signature, a different file structure), open and edit that downstream ticket file *before* moving on.
- Flag the change to the human so they're aware.
- Never silently diverge from the plan — if in doubt, ask.
