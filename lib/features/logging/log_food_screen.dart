import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/models/food_result.dart';
import '../../core/database/database.dart';
import '../../providers/data_trigger_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/food_search_provider.dart';
import '../recipes/recipe_list_screen.dart';
import 'widgets/barcode_scanner.dart';
import 'widgets/food_search_delegate.dart';
import 'widgets/manual_food_form.dart';
import 'widgets/meal_type_selector.dart';
import 'widgets/quick_food_log_sheet.dart';
import 'widgets/serving_size_picker.dart';

class LogFoodScreen extends ConsumerStatefulWidget {
  const LogFoodScreen({super.key});

  @override
  ConsumerState<LogFoodScreen> createState() => _LogFoodScreenState();
}

class _LogFoodScreenState extends ConsumerState<LogFoodScreen> {
  FoodSearchItem? _selectedFood;
  FoodSearchItem? _quickLogItem;
  double _servings = 1.0;
  String _unit = 'serving';
  String? _mealType;
  bool _saving = false;
  bool _pendingCreateCustom = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onSearch() async {
    final searchService = ref.read(foodSearchServiceProvider);
    final result = await showSearch<FoodSearchItem?>(
      context: context,
      delegate: FoodSearchDelegate(
        searchService: searchService,
        onCreateCustomFood: () => _pendingCreateCustom = true,
        onQuickLog: (item) => _quickLogItem = item,
      ),
    );

    if (_quickLogItem != null) {
      final item = _quickLogItem!;
      _quickLogItem = null;
      _showQuickLogSheet(item);
    } else if (result != null) {
      _selectFood(result);
    } else if (_pendingCreateCustom) {
      _pendingCreateCustom = false;
      _openCreateCustom();
    }
  }

  void _selectFood(FoodSearchItem food) {
    setState(() {
      _selectedFood = food;
      _servings = food.servingQuantity;
      _unit = food.servingUnit;
      _mealType = null;
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

  Future<void> _showQuickLogSheet(FoodSearchItem item) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickFoodLogSheet(food: item),
    );
  }

  Future<void> _onDuplicate(FoodEntry entry) async {
    final foodId = entry.foodId;
    if (foodId == null) return;
    final db = ref.read(databaseProvider);
    final food = await db.getFoodById(foodId);
    if (food == null || !mounted) return;
    final item = FoodSearchItem.fromFood(food);
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickFoodLogSheet(
        food: item,
        sourceEntry: entry,
      ),
    );
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
  }

  void _onUnitChanged(String value) {
    setState(() => _unit = value);
  }

  String _buildLabel(double qty, String unit) {
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
    return '$qtyStr $unit';
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
        servingLabel: _buildLabel(_servings, _unit),
        barcode: Value(food.barcode),
        foodId: Value(foodId),
        recipeId: const Value(null),
        mealType: _mealType!,
        loggedAt: now,
      ));

      ref.invalidate(todaysFoodProvider);
      ref.read(dataTriggerProvider.notifier).state++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food logged!')),
        );
        setState(() {
          _selectedFood = null;
          _servings = 1.0;
          _unit = 'serving';
          _mealType = null;
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
    final sq = _selectedFood != null
        ? (_selectedFood!.servingQuantity > 0
            ? _selectedFood!.servingQuantity
            : 1)
        : 1;

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
                                    _unit = 'serving';
                                    _mealType = null;
                                  }),
                                )
                              : null,
                        ),
                      ),
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
                            ref.read(dataTriggerProvider.notifier).state++;
                          }
                        },
                        icon: const Icon(Icons.book),
                        label: const Text('Recipes'),
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
                      quantity: _servings,
                      unit: _unit,
                      onQuantityChanged: _onServingsChanged,
                      onUnitChanged: _onUnitChanged,
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
                              'Macros for ${_buildLabel(_servings, _unit)}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            _macroRow(
                              'Calories',
                              (_selectedFood!.caloriesPerServing * (_servings / sq)).toStringAsFixed(0),
                              null,
                            ),
                            const SizedBox(height: 4),
                            _macroRow(
                              'Protein',
                              (_selectedFood!.proteinPerServing * (_servings / sq)).toStringAsFixed(1),
                              'g',
                            ),
                            const SizedBox(height: 4),
                            _macroRow(
                              'Carbs',
                              (_selectedFood!.carbsPerServing * (_servings / sq)).toStringAsFixed(1),
                              'g',
                            ),
                            const SizedBox(height: 4),
                            _macroRow(
                              'Fat',
                              (_selectedFood!.fatPerServing * (_servings / sq)).toStringAsFixed(1),
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
          ] else
            Expanded(
              child: _TodayEntriesSection(
                onDuplicate: _onDuplicate,
              ),
            ),
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

class _TodayEntriesSection extends ConsumerWidget {
  final ValueChanged<FoodEntry>? onDuplicate;

  const _TodayEntriesSection({this.onDuplicate});

  String? _timeFromLoggedAt(String loggedAt) {
    if (loggedAt.length >= 16) return loggedAt.substring(11, 16);
    return null;
  }

  Map<String, List<FoodEntry>> _groupByMealType(List<FoodEntry> entries) {
    final map = <String, List<FoodEntry>>{};
    for (final entry in entries) {
      map.putIfAbsent(entry.mealType.isNotEmpty ? entry.mealType : 'other', () => []).add(entry);
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayEntries = ref.watch(todaysFoodProvider);
    return todayEntries.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Text(
              'No entries logged today',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }

        final groups = _groupByMealType(entries);
        final mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
        final sortedMeals = groups.keys.toList()
          ..sort((a, b) {
            final ai = mealOrder.indexOf(a);
            final bi = mealOrder.indexOf(b);
            if (ai == -1 && bi == -1) return a.compareTo(b);
            if (ai == -1) return 1;
            if (bi == -1) return -1;
            return ai.compareTo(bi);
          });

        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                "Today's Entries",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            for (final mealType in sortedMeals) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Text(
                  mealType[0].toUpperCase() + mealType.substring(1),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              for (final entry in groups[mealType]!) ...[
                ListTile(
                  title: Text(entry.name),
                  subtitle: Text(
                    '${entry.calories.toInt()} cal  •  P${entry.proteinGrams.toStringAsFixed(0)}g  C${entry.carbsGrams.toStringAsFixed(0)}g  F${entry.fatGrams.toStringAsFixed(0)}g${_timeFromLoggedAt(entry.loggedAt) != null ? '  •  ${_timeFromLoggedAt(entry.loggedAt)}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onDuplicate != null && entry.foodId != null)
                      IconButton(
                        icon: const Icon(Icons.replay),
                        tooltip: 'Duplicate entry',
                        onPressed: () => onDuplicate!(entry),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Failed to load today\'s entries'),
      ),
    );
  }

}
