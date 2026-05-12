# T2 — App shell + navigation + theme

Create the app scaffold with bottom navigation and Material 3 theme.

## Files to create

- `lib/app.dart` — `MaterialApp` with theme + bottom nav
- `lib/theme/theme.dart` — light + dark `ThemeData`
- `lib/features/dashboard/dashboard_screen.dart` — placeholder
- `lib/features/logging/log_food_screen.dart` — placeholder
- `lib/features/bodyweight/bodyweight_screen.dart` — placeholder
- `lib/features/history/history_screen.dart` — placeholder
- `lib/features/goals/goals_screen.dart` — placeholder

## Files to modify

- `lib/main.dart` — wrap in `ProviderScope`, call `runApp(App())`

## Acceptance criteria

- App launches, shows 5-tab bottom navigation bar
- Tapping each tab switches to the corresponding placeholder screen
- Theme switches between light and dark (via system setting)
- Layout handles safe areas on all platforms

## Technical notes

- Use `Scaffold` + `NavigationBar` (Material 3). No router package needed for now — manage tab index with a `StatefulWidget` or simple Riverpod `StateProvider<int>`.
- Theme: seed from `Colors.deepPurple` (matching Flutter default for now), can be refined later.
