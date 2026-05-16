import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../providers/data_trigger_provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/food_log_provider.dart';
import '../../../providers/food_search_provider.dart';
import 'meal_type_selector.dart';
import 'serving_size_picker.dart';

class QuickFoodLogSheet extends ConsumerStatefulWidget {
  final FoodSearchItem food;
  final FoodEntry? sourceEntry;
  final DateTime? loggedAt;

  const QuickFoodLogSheet({
    super.key,
    required this.food,
    this.sourceEntry,
    this.loggedAt,
  });

  @override
  ConsumerState<QuickFoodLogSheet> createState() => _QuickFoodLogSheetState();
}

class _QuickFoodLogSheetState extends ConsumerState<QuickFoodLogSheet> {
  late double _servings;
  late String _unit;
  String? _mealType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.sourceEntry != null) {
      _servings = widget.sourceEntry!.servings;
      _unit = widget.food.servingUnit;
    } else {
      _servings = widget.food.servingQuantity;
      _unit = widget.food.servingUnit;
    }
  }

  Future<void> _log() async {
    if (_mealType == null) return;
    setState(() => _saving = true);

    final food = widget.food;
    final db = ref.read(databaseProvider);
    final now = (widget.loggedAt ?? DateTime.now()).toIso8601String();

    try {
      int? foodId = food.localId;

      if (foodId == null && food.source == 'open_food_facts') {
        foodId = await db.insertFood(FoodsCompanion.insert(
          name: food.name,
          servingLabel: food.servingLabel,
          servingQuantity: Value(food.servingQuantity),
          servingUnit: Value(food.servingUnit),
          caloriesPerServing: food.caloriesPerServing,
          proteinPerServing: food.proteinPerServing,
          carbsPerServing: food.carbsPerServing,
          fatPerServing: food.fatPerServing,
          barcode: Value(food.barcode),
          brand: Value(food.brand),
          source: Value(food.source),
          createdAt: now,
        ));
      }

      final sq = food.servingQuantity > 0 ? food.servingQuantity : 1;
      await db.insertEntry(FoodEntriesCompanion.insert(
        name: food.name,
        calories: food.caloriesPerServing * (_servings / sq),
        proteinGrams: food.proteinPerServing * (_servings / sq),
        carbsGrams: food.carbsPerServing * (_servings / sq),
        fatGrams: food.fatPerServing * (_servings / sq),
        servings: _servings,
        servingLabel: _unit,
        barcode: Value(food.barcode),
        foodId: Value(foodId),
        recipeId: const Value(null),
        mealType: _mealType!,
        loggedAt: now,
      ));

      ref.invalidate(todaysFoodProvider);
      ref.read(dataTriggerProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to log: $e'),
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
    final sq = widget.food.servingQuantity > 0
        ? widget.food.servingQuantity
        : 1;

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
            widget.food.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniMacro(
                    'Cal',
                    (widget.food.caloriesPerServing * (_servings / sq))
                        .toStringAsFixed(0),
                    '',
                  ),
                  _miniMacro(
                    'P',
                    (widget.food.proteinPerServing * (_servings / sq))
                        .toStringAsFixed(1),
                    'g',
                  ),
                  _miniMacro(
                    'C',
                    (widget.food.carbsPerServing * (_servings / sq))
                        .toStringAsFixed(1),
                    'g',
                  ),
                  _miniMacro(
                    'F',
                    (widget.food.fatPerServing * (_servings / sq))
                        .toStringAsFixed(1),
                    'g',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ServingSizePicker(
            quantity: _servings,
            unit: _unit,
            onQuantityChanged: (v) => setState(() => _servings = v),
            onUnitChanged: (v) => setState(() => _unit = v),
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
              onPressed: (_mealType != null && !_saving) ? _log : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log entry'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _miniMacro(String label, String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          '$label$unit',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
