import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/models/food_result.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/food_search_provider.dart';
import '../recipes/recipe_list_screen.dart';
import 'widgets/barcode_scanner.dart';
import 'widgets/food_search_delegate.dart';
import 'widgets/manual_food_form.dart';
import 'widgets/meal_templates.dart';
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

  Future<void> _onSaveAsTemplate() async {
    final db = ref.read(databaseProvider);
    final food = _selectedFood!;
    await saveCurrentFoodsAsTemplate(
      context,
      db,
      (_) => FoodEntry(
        id: 0,
        name: food.name,
        calories: food.caloriesPerServing * _servings,
        proteinGrams: food.proteinPerServing * _servings,
        carbsGrams: food.carbsPerServing * _servings,
        fatGrams: food.fatPerServing * _servings,
        servings: _servings,
        servingLabel: food.servingLabel,
        mealType: _mealType ?? '',
        loggedAt: '',
      ),
      1,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template saved!')),
    );
  }

  Future<void> _openTemplates() async {
    final foods = await showModalBottomSheet<List<TemplateFood>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const MealTemplatesSheet(),
    );
    if (foods == null || !mounted) return;

    final db = ref.read(databaseProvider);
    final now = DateTime.now().toIso8601String();
    try {
      for (final f in foods) {
        await db.insertEntry(FoodEntriesCompanion.insert(
          name: f.name,
          calories: f.calories,
          proteinGrams: f.proteinGrams,
          carbsGrams: f.carbsGrams,
          fatGrams: f.fatGrams,
          servings: f.servings,
          servingLabel: f.servingLabel,
          mealType: 'snack',
          loggedAt: now,
        ));
      }
      ref.invalidate(todaysFoodProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template foods added!')),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to add template foods: $e'),
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

  Future<void> _onBarcodeScan() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcode scanning is not supported on web'),
        ),
      );
      return;
    }

    final apiClient = ref.read(openFoodFactsClientProvider);
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(apiClient: apiClient),
      ),
    );

    if (!mounted) return;

    if (result is FoodResult) {
      _selectFood(FoodSearchItem.fromFoodResult(result));
    } else if (result == 'manual') {
      _openCreateCustom();
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                    ),
                    if (_selectedFood != null)
                      IconButton(
                        key: const Key('save_as_template_button'),
                        icon: const Icon(Icons.bookmark_add_outlined),
                        onPressed: _onSaveAsTemplate,
                        tooltip: 'Save as template',
                      ),
                    IconButton(
                      key: const Key('barcode_scan_button'),
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _onBarcodeScan,
                      tooltip: 'Scan barcode',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child:                       OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const RecipeListScreen(pickerMode: true),
                            ),
                          );
                          if (result == true && mounted) {
                            ref.invalidate(todaysFoodProvider);
                          }
                        },
                        icon: const Icon(Icons.book),
                        label: const Text('Recipes'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('templates_button'),
                        onPressed: () => _openTemplates(),
                        icon: const Icon(Icons.content_paste),
                        label: const Text('Templates'),
                      ),
                    ),
                  ],
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
