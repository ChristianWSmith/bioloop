import 'package:flutter/material.dart';
import '../../../providers/macro_targets_provider.dart';

class MacroBars extends StatelessWidget {
  final MacroTargets targets;
  final double consumedCalories;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;

  const MacroBars({
    super.key,
    required this.targets,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MacroRow(
              label: 'Calories',
              consumed: consumedCalories,
              target: targets.targetCalories,
              unit: 'kcal',
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            _ProgressBar(
              value: targets.targetCalories > 0
                  ? consumedCalories / targets.targetCalories
                  : 0.0,
              color: Theme.of(context).colorScheme.primary,
              isOver: targets.targetCalories > 0 && consumedCalories > targets.targetCalories,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MacroColumn(
                    label: 'Protein',
                    consumed: consumedProtein,
                    target: targets.proteinGrams,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroColumn(
                    label: 'Carbs',
                    consumed: consumedCarbs,
                    target: targets.carbsGrams,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroColumn(
                    label: 'Fat',
                    consumed: consumedFat,
                    target: targets.fatGrams,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final double consumed;
  final double target;
  final String unit;
  final Color color;

  const _MacroRow({
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = target > 0 && consumed > target;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isOver ? Colors.red : color,
              ),
        ),
        Text(
          '${consumed.toInt()} / ${target.toInt()} $unit',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final bool isOver;

  const _ProgressBar({required this.value, required this.color, this.isOver = false});

  @override
  Widget build(BuildContext context) {
    final barColor = isOver && value > 1.0 ? Colors.red : color;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: barColor.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation(barColor),
        minHeight: 8,
      ),
    );
  }
}

class _MacroColumn extends StatelessWidget {
  final String label;
  final double consumed;
  final double target;
  final Color color;

  const _MacroColumn({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = target > 0 && consumed > target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isOver ? Colors.red : color,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          '${consumed.toInt()} / ${target.toInt()} g',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        _ProgressBar(
          value: target > 0 ? (consumed / target) : 0.0,
          color: color,
          isOver: isOver,
        ),
      ],
    );
  }
}
