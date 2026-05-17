import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/reset_provider.dart';

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
    switch (color.toARGB32()) {
      case 0xfff44336:
        return 'Red';
      case 0xffe91e63:
        return 'Pink';
      case 0xff9c27b0:
        return 'Purple';
      case 0xff673ab7:
        return 'Deep Purple';
      case 0xff3f51b5:
        return 'Indigo';
      case 0xff2196f3:
        return 'Blue';
      case 0xff009688:
        return 'Teal';
      case 0xff4caf50:
        return 'Green';
      default:
        return 'Custom';
    }
  }

  Future<void> _pickAccentColor(BuildContext context, WidgetRef ref) async {
    final goalsAsync = await ref.read(userGoalsProvider.future);
    if (!context.mounted) return;
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
                final isSelected =
                    color.toARGB32() == currentColor.toARGB32();
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
                                ? Theme.of(ctx).colorScheme.primary
                                : Colors.grey.shade300,
                            width: isSelected ? 4 : 2,
                          ),
                        ),
                        width: 48,
                        height: 48,
                      ),
                      if (isSelected)
                        const Icon(
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

    if (selectedColor != null && context.mounted && goalsAsync != null) {
      final db = ref.read(databaseProvider);
      await db.upsertGoals(UserGoalsCompanion(
        id: const Value(1),
        goalType: Value(goalsAsync.goalType),
        calorieAdjustment: Value(goalsAsync.calorieAdjustment),
        proteinGPerLb: Value(goalsAsync.proteinGPerLb),
        fatCaloriePct: Value(goalsAsync.fatCaloriePct),
        sex: Value(goalsAsync.sex),
        heightCm: Value(goalsAsync.heightCm),
        birthdate: Value(goalsAsync.birthdate),
        age: Value(goalsAsync.age),
        useImperial: Value(goalsAsync.useImperial),
        activityLevel: Value(goalsAsync.activityLevel),
        onboardingCompleted: Value(goalsAsync.onboardingCompleted),
        accentColorSeed: Value(selectedColor.toARGB32()),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));
      ref.invalidate(userGoalsProvider);
    }
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will delete all your food logs, bodyweight entries, '
          'saved foods, and goals. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final db = ref.read(databaseProvider);
              await db.resetAll();
              ref.read(resetTriggerProvider.notifier).state++;
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
}
