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
