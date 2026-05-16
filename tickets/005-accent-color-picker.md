# Ticket 5: Accent Color Picker in Settings

**Priority:** Medium  
**Complexity:** Medium  
**Estimated effort:** 45 minutes  
**Files:** `lib/features/settings/settings_screen.dart`

---

## Description

Add a color picker UI to the Settings screen that lets users choose their accent color from a predefined palette.

---

## Context

From `DISCOVERY.md`:

> The Settings screen currently only has a "Reset All Data" option. We need to add an "Accent Color" option that opens a color picker dialog/bottom sheet.

**Design decisions:**
- **UI pattern:** Dialog (more standard for settings)
- **Palette:** 8 Material primary colors
- **Preview:** Show current color as a swatch in the settings tile

**Suggested color palette:**
1. Red (`Colors.red`)
2. Pink (`Colors.pink`)
3. Purple (`Colors.purple`)
4. Deep Purple (`Colors.deepPurple`) — default
5. Indigo (`Colors.indigo`)
6. Blue (`Colors.blue`)
7. Teal (`Colors.teal`)
8. Green (`Colors.green`)

---

## Acceptance Criteria

- [ ] New ListTile "Accent Color" with preview swatch in Settings
- [ ] Tapping opens a dialog with color palette
- [ ] Predefined palette of 8 Material primary colors
- [ ] Selected color saves to `user_goals` table via `goalsProvider`
- [ ] Theme updates immediately after selection
- [ ] Current selection is highlighted in palette
- [ ] Dialog has "Cancel" and "Save" buttons (or just saves on tap)
- [ ] Code compiles without errors

---

## Implementation

**File:** `lib/features/settings/settings_screen.dart`

### Step 1: Add imports
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/reset_provider.dart';
import '../../providers/goals_provider.dart';  // for saving color
import 'dart:io';  // for Platform check if needed
```

### Step 2: Add color palette constant
```dart
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _colorPalette = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.teal,
    Colors.green,
  ];
```

### Step 3: Add color picker method
```dart
  Future<void> _pickAccentColor(BuildContext context, WidgetRef ref) async {
    final goalsAsync = await ref.read(userGoalsProvider.future);
    final currentColor = goalsAsync?.accentColorSeed != null
        ? Color(goalsAsync!.accentColorSeed!)
        : Colors.deepPurple;

    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Accent Color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _colorPalette.length,
              itemBuilder: (_, index) {
                final color = _colorPalette[index];
                final isSelected = color.value == currentColor.value;
                return GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(color),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 4 : 2,
                          ),
                        ),
                        width: 48,
                        height: 48,
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedColor != null && context.mounted) {
      // Save to database
      final goalsService = ref.read(goalsProvider);
      final existingGoals = goalsAsync;
      await goalsService.updateGoals(existingGoals!.copyWith(
        accentColorSeed: selectedColor.value,
      ));
      
      // Invalidate to trigger theme refresh
      ref.invalidate(userGoalsProvider);
    }
  }
```

### Step 4: Add ListTile to build method
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(userGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          goalsAsync.when(
            data: (goals) {
              final accentColor = goals?.accentColorSeed != null
                  ? Color(goals!.accentColorSeed!)
                  : Colors.deepPurple;
              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                title: const Text('Accent Color'),
                subtitle: Text(
                  _getColorName(accentColor),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickAccentColor(context, ref),
              );
            },
            loading: () => const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Accent Color'),
            ),
            error: (_, _) => const ListTile(
              title: Text('Accent Color'),
              subtitle: Text('Failed to load'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Data Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Reset All Data'),
            subtitle: const Text('Delete everything and start fresh'),
            onTap: () => _showResetDialog(context, ref),
          ),
        ],
      ),
    );
  }

  String _getColorName(Color color) {
    switch (color.value) {
      case 0xfff44336: return 'Red';
      case 0xffe91e63: return 'Pink';
      case 0xff9c27b0: return 'Purple';
      case 0xff673ab7: return 'Deep Purple';
      case 0xff3f51b5: return 'Indigo';
      case 0xff2196f3: return 'Blue';
      case 0xff009688: return 'Teal';
      case 0xff4caf50: return 'Green';
      default: return 'Custom';
    }
  }
```

### Step 5: Update `GoalsService` to support updating accent color

**File:** `lib/providers/goals_provider.dart`

Add method to update existing goals with new color:
```dart
class GoalsService {
  final AppDatabase db;
  GoalsService({required this.db});

  // ... existing methods ...

  Future<void> updateGoals(UserGoalsCompanion goals) async {
    await db.upsertGoals(goals);
  }
}
```

**Note:** May need to check if `UserGoalsCompanion` has `accentColorSeed` field after Ticket 3 is complete.

---

## Testing Plan

### Manual Testing
1. **Open Settings:**
   - [ ] "Accent Color" tile appears under "Appearance" section
   - [ ] Current color shown as circular swatch
   - [ ] Color name displayed (e.g., "Deep Purple")

2. **Open color picker:**
   - [ ] Dialog opens with 8 color circles in 4x2 grid
   - [ ] Current color has checkmark and primary-colored border
   - [ ] Other colors have grey border

3. **Select new color:**
   - [ ] Tap a color → dialog closes
   - [ ] Theme updates immediately (buttons, progress bars change color)
   - [ ] Settings tile shows new color swatch and name

4. **Cancel:**
   - [ ] Tap "Cancel" → dialog closes
   - [ ] Color unchanged

5. **Persistence:**
   - [ ] Restart app → color persists
   - [ ] Navigate between tabs → color persists

### Verification
- [ ] Run `flutter analyze > analyze.log 2>&1` and read `analyze.log` — zero issues
- [ ] Run `flutter test > test.log 2>&1` and read `test.log` — all tests pass

---

## Dependencies

- **Requires:** Ticket 3 (database column), Ticket 4 (dynamic theme system)
- **Required by:** None — this completes the accent color feature

---

## Notes

- Dialog pattern chosen over bottom sheet for consistency with settings conventions
- Grid layout (4x2) ensures all colors visible without scrolling
- Checkmark on selected color provides clear visual feedback
- Color name helper method improves accessibility
- Theme updates reactively via Riverpod invalidation
