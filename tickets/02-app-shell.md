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

## Testing

- **Widget — render**: app renders without errors, 5 bottom nav items visible
- **Widget — tab switching**: tapping each nav item switches the body to the correct placeholder screen (check for unique text key in each)
- **Widget — theme**: wrap in `MediaQuery` with `PlatformDispatcher.textScaleFactor` override; verify light/dark `ThemeData` is applied correctly
- **Widget — safe areas**: render in landscape orientation, verify content respects safe areas

Use `tester.pumpWidget(ProviderScope(child: App()))` in widget tests. Provide `overrides` for any required providers that aren't wired yet.

## Technical notes

- Use `Scaffold` + `NavigationBar` (Material 3). No router package needed for now — manage tab index with a `StatefulWidget` or simple Riverpod `StateProvider<int>`.
- Theme: seed from `Colors.deepPurple` (matching Flutter default for now), can be refined later.
