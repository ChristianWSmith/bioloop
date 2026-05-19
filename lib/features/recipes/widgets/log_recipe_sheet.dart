import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/data_trigger_provider.dart';
import '../../../providers/food_log_provider.dart';
import '../../../providers/recipe_provider.dart';
import '../../logging/widgets/meal_type_selector.dart';

class LogRecipeSheet extends ConsumerStatefulWidget {
  final RecipeDetail detail;
  final DateTime? loggedAt;

  const LogRecipeSheet({super.key, required this.detail, this.loggedAt});

  @override
  ConsumerState<LogRecipeSheet> createState() => _LogRecipeSheetState();
}

class _LogRecipeSheetState extends ConsumerState<LogRecipeSheet> {
  final _portionController = TextEditingController(text: '100');
  String? _mealType;

  @override
  void dispose() {
    _portionController.dispose();
    super.dispose();
  }

  double get _portion => double.tryParse(_portionController.text) ?? 0;
  double get _scale => widget.detail.recipe.servingSize > 0
      ? _portion / widget.detail.recipe.servingSize
      : 1;

  Future<void> _log() async {
    if (_mealType == null) return;
    try {
      await ref.read(recipeServiceProvider).logRecipe(
            recipeId: widget.detail.recipe.id,
            portion: _portion,
            mealType: _mealType!,
            loggedAt: widget.loggedAt,
          );
      ref.invalidate(todaysFoodProvider);
      ref.read(dataTriggerProvider.notifier).state++;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to log recipe: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.detail.recipe;
    final macros = widget.detail.macros;
    final scaledCals = macros.calories * _scale;
    final scaledProtein = macros.proteinGrams * _scale;
    final scaledCarbs = macros.carbsGrams * _scale;
    final scaledFat = macros.fatGrams * _scale;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ${macros.calories.toStringAsFixed(0)} kcal · ${macros.fatGrams.toStringAsFixed(1)}f · ${macros.carbsGrams.toStringAsFixed(1)}c · ${macros.proteinGrams.toStringAsFixed(1)}p',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Per unit: ${macros.perUnitCalories.toStringAsFixed(1)} kcal / ${recipe.servingLabel}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _portionController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Portion (${recipe.servingLabel})',
              suffixText: recipe.servingLabel,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            '${_scale.toStringAsFixed(3)}× recipe — ${scaledCals.toStringAsFixed(0)} kcal · ${scaledFat.toStringAsFixed(1)}f · ${scaledCarbs.toStringAsFixed(1)}c · ${scaledProtein.toStringAsFixed(1)}p',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 16),
          MealTypeSelector(
            selected: _mealType,
            onChanged: (type) => setState(() => _mealType = type),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_mealType != null && _portion > 0) ? _log : null,
              child: const Text('Log entry'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
