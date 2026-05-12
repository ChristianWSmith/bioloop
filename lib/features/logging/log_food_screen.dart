import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/food_search_provider.dart';
import 'widgets/food_search_delegate.dart';
import 'widgets/manual_food_form.dart';
import 'widgets/meal_type_selector.dart';
import 'widgets/serving_size_picker.dart';

class LogFoodScreen extends ConsumerStatefulWidget {
  const LogFoodScreen({super.key});

  @override
  ConsumerState<LogFoodScreen> createState() => _LogFoodScreenState();
}

class _LogFoodScreenState extends ConsumerState<LogFoodScreen> {
  FoodSearchItem? _selectedFood;
  double _servings = 1.0;
  String? _mealType;
  bool _saving = false;
  bool _pendingCreateCustom = false;
  bool _updatingGram = false;

  final _gramController = TextEditingController();

  @override
  void dispose() {
    _gramController.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final searchService = ref.read(foodSearchServiceProvider);
    final result = await showSearch<FoodSearchItem?>(
      context: context,
      delegate: FoodSearchDelegate(
        searchService: searchService,
        onCreateCustomFood: () => _pendingCreateCustom = true,
      ),
    );

    if (result != null) {
      _selectFood(result);
    } else if (_pendingCreateCustom) {
      _pendingCreateCustom = false;
      _openCreateCustom();
    }
  }

  void _selectFood(FoodSearchItem food) {
    setState(() {
      _selectedFood = food;
      _servings = 1.0;
      _mealType = null;
      _gramController.clear();
    });
  }

  Future<void> _openCreateCustom() async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => const ManualFoodForm(),
      ),
    );
    if (food != null && mounted) {
      _selectFood(FoodSearchItem.fromFood(food));
    }
  }

  void _onServingsChanged(double value) {
    setState(() => _servings = value);
    _syncGramFromServings();
  }

  void _onGramChanged(String value) {
    if (_updatingGram) return;
    if (_selectedFood?.servingSizeGrams == null) return;
    if (value.isEmpty) return;
    final grams = double.tryParse(value);
    if (grams != null && grams > 0) {
      final newServings = grams / _selectedFood!.servingSizeGrams!;
      if ((newServings - _servings).abs() > 0.0001) {
        setState(() => _servings = newServings);
      }
    }
  }

  void _syncGramFromServings() {
    if (_selectedFood?.servingSizeGrams != null) {
      _updatingGram = true;
      _gramController.text =
          (_servings * _selectedFood!.servingSizeGrams!).toStringAsFixed(1);
      _updatingGram = false;
    }
  }

  Future<void> _save() async {
    if (_mealType == null || _selectedFood == null) return;
    setState(() => _saving = true);

    final food = _selectedFood!;
    final db = ref.read(databaseProvider);
    final now = DateTime.now().toIso8601String();

    try {
      int? foodId = food.localId;

      if (foodId == null && food.source == 'open_food_facts') {
        foodId = await db.insertFood(FoodsCompanion.insert(
          name: food.name,
          servingLabel: food.servingLabel,
          servingSizeGrams: Value(food.servingSizeGrams),
          caloriesPerServing: food.caloriesPerServing,
          proteinPerServing: food.proteinPerServing,
          carbsPerServing: food.carbsPerServing,
          fatPerServing: food.fatPerServing,
          barcode: Value(food.barcode),
          source: Value(food.source),
          createdAt: now,
        ));
      }

      await db.insertEntry(FoodEntriesCompanion.insert(
        name: food.name,
        calories: food.caloriesPerServing * _servings,
        proteinGrams: food.proteinPerServing * _servings,
        carbsGrams: food.carbsPerServing * _servings,
        fatGrams: food.fatPerServing * _servings,
        servings: _servings,
        servingLabel: food.servingLabel,
        barcode: Value(food.barcode),
        foodId: Value(foodId),
        recipeId: const Value(null),
        mealType: _mealType!,
        loggedAt: now,
      ));

      ref.invalidate(todaysFoodProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food logged!')),
        );
        setState(() {
          _selectedFood = null;
          _servings = 1.0;
          _mealType = null;
          _gramController.clear();
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save: $e'),
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
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                TextField(
                  key: const Key('food_search_field'),
                  readOnly: true,
                  onTap: _onSearch,
                  decoration: InputDecoration(
                    hintText: _selectedFood != null
                        ? _selectedFood!.name
                        : 'Search foods...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _selectedFood != null
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _selectedFood = null;
                              _servings = 1.0;
                              _mealType = null;
                              _gramController.clear();
                            }),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Recipes — coming in a future update',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.book),
                    label: const Text('Recipes'),
                  ),
                ),
              ],
            ),
          ),

          if (_selectedFood != null) ...[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  const Divider(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ServingSizePicker(
                      servings: _servings,
                      onChanged: _onServingsChanged,
                      servingSizeGrams: _selectedFood!.servingSizeGrams,
                      gramController: _gramController,
                      onGramChanged: _onGramChanged,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Macros for ${_servings.toStringAsFixed(_servings == _servings.roundToDouble() ? 0 : 1)} × ${_selectedFood!.servingLabel}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            _macroRow(
                              'Calories',
                              (_selectedFood!.caloriesPerServing * _servings).toStringAsFixed(0),
                              null,
                            ),
                            const SizedBox(height: 4),
                            _macroRow(
                              'Protein',
                              (_selectedFood!.proteinPerServing * _servings).toStringAsFixed(1),
                              'g',
                            ),
                            const SizedBox(height: 4),
                            _macroRow(
                              'Carbs',
                              (_selectedFood!.carbsPerServing * _servings).toStringAsFixed(1),
                              'g',
                            ),
                            const SizedBox(height: 4),
                            _macroRow(
                              'Fat',
                              (_selectedFood!.fatPerServing * _servings).toStringAsFixed(1),
                              'g',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MealTypeSelector(
                      selected: _mealType,
                      onChanged: (type) => setState(() => _mealType = type),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (_mealType != null && !_saving) ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ),
          ] else ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Tap the search bar above to find or create a food',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const Spacer(),
          ],
        ],
      ),
    );
  }

  Widget _macroRow(String label, String value, String? unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          '$value${unit != null ? ' $unit' : ''}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
