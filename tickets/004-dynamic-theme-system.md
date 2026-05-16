# Ticket 4: Dynamic Theme System

**Priority:** Medium  
**Complexity:** Medium  
**Estimated effort:** 30 minutes  
**Files:** `lib/theme/theme.dart`, `lib/app.dart`

---

## Description

Update the theme system to accept an optional seed color and wire it up to the user's preference from the database.

---

## Context

From `DISCOVERY.md`:

> The `AppTheme` class currently hardcodes `Colors.deepPurple`. We need to make it dynamic so the theme updates based on the user's saved preference.

**Current theme flow:**
```
app.dart → MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark)
                  ↓
theme.dart → ColorScheme.fromSeed(seedColor: Colors.deepPurple)  // hardcoded
```

**New theme flow:**
```
app.dart → watch userGoalsProvider → extract accentColorSeed
                  ↓
          convert int to Color (or null)
                  ↓
theme.dart → ColorScheme.fromSeed(seedColor: seedColor ?? Colors.deepPurple)
```

---

## Acceptance Criteria

- [ ] `AppTheme.light()` accepts optional `Color? seedColor` parameter
- [ ] `AppTheme.dark()` accepts optional `Color? seedColor` parameter
- [ ] When `seedColor` is null, defaults to `Colors.deepPurple`
- [ ] `app.dart` reads `accentColorSeed` from `userGoalsProvider`
- [ ] Theme updates reactively when user changes color preference
- [ ] Both light and dark modes use the same seed color
- [ ] Code compiles without errors

---

## Implementation

### File 1: `lib/theme/theme.dart`

**Current code:**
```dart
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  );
}
```

**Updated code:**
```dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light([Color? seedColor]) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor ?? Colors.deepPurple,
    ),
  );

  static ThemeData dark([Color? seedColor]) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor ?? Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  );
}
```

### File 2: `lib/app.dart`

**Current code (lines 58-69):**
```dart
@override
Widget build(BuildContext context) {
  ref.listen<int>(resetTriggerProvider, (_, _) {
    _checkOnboarding();
  });

  return MaterialApp(
    title: 'BioLoop',
    themeMode: ThemeMode.system,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: _buildHome(),
  );
}
```

**Updated code:**
```dart
@override
Widget build(BuildContext context) {
  ref.listen<int>(resetTriggerProvider, (_, _) {
    _checkOnboarding();
  });

  final goalsAsync = ref.watch(userGoalsProvider);
  final seedColor = goalsAsync.when(
    data: (goals) => goals?.accentColorSeed != null
        ? Color(goals!.accentColorSeed!)
        : null,
    loading: () => null,
    error: (_, _) => null,
  );

  return MaterialApp(
    title: 'BioLoop',
    themeMode: ThemeMode.system,
    theme: AppTheme.light(seedColor),
    darkTheme: AppTheme.dark(seedColor),
    home: _buildHome(),
  );
}
```

**Add import:**
```dart
import 'providers/goals_provider.dart';  // for userGoalsProvider
```

---

## Testing Plan

### Manual Testing
1. **Before color change:**
   - [ ] App starts with deepPurple accent color
   - [ ] Check buttons, progress indicators, switches — all purple

2. **After implementing Ticket 5 (color picker):**
   - [ ] Change accent color in Settings
   - [ ] Theme updates immediately
   - [ ] Navigate between screens — color persists
   - [ ] Restart app — color persists

3. **Light/dark mode:**
   - [ ] Switch system to dark mode
   - [ ] Accent color remains consistent
   - [ ] Switch back to light mode
   - [ ] Accent color remains consistent

### Verification
- [ ] Run `flutter analyze > analyze.log 2>&1` and read `analyze.log` — zero issues
- [ ] Run `flutter test > test.log 2>&1` and read `test.log` — all tests pass

---

## Dependencies

- **Requires:** Ticket 3 (database column for `accentColorSeed`)
- **Required by:** Ticket 5 (color picker UI)

---

## Notes

- `userGoalsProvider` is a `FutureProvider<UserGoal?>`, so we need to handle loading/error states
- When `accentColorSeed` is `null`, the theme falls back to `Colors.deepPurple`
- Material 3's `ColorScheme.fromSeed()` handles both light and dark brightness automatically
- Theme updates reactively because we're using Riverpod's `ref.watch()`
