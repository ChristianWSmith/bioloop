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
- `test/widget_test.dart` — single widget smoke test
- No CI, no custom build tooling, no assets
- Default `flutter_lints` lint rules via `analysis_options.yaml`

## App State

| Ticket | Status | Date | Agent |
|--------|--------|------|-------|
| T0 — Initial scaffold | ✅ Complete | — | Manual |

After completing each ticket, the agent working on it appends a new row here. This table
is the single source of truth for what has been built.
