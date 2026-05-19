import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/recipe_provider.dart';
import '../logging/widgets/food_search_delegate.dart';
import '../logging/widgets/manual_food_form.dart';
import '../../providers/food_search_provider.dart';
import 'widgets/recipe_ingredient_row.dart';
import 'widgets/log_recipe_sheet.dart';

class RecipeFormScreen extends ConsumerStatefulWidget {
  final int? recipeId;

  const RecipeFormScreen({super.key, this.recipeId});

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final _nameController = TextEditingController();
  final _servingSizeController = TextEditingController();
  final _servingLabelController = TextEditingController(text: 'g');
  List<IngredientWithFood> _ingredients = [];
  bool _isLoading = true;
  bool _isSaving = false;
  final bool _readOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      _loadRecipe();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadRecipe() async {
    final detail = await ref.read(recipeDetailProvider(widget.recipeId!).future);
    if (detail == null || !mounted) return;
    setState(() {
      _nameController.text = detail.recipe.name;
      _servingSizeController.text =
          detail.recipe.servingSize.toStringAsFixed(0);
      _servingLabelController.text = detail.recipe.servingLabel;
      _ingredients = detail.ingredients;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingSizeController.dispose();
    _servingLabelController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _ingredients.isNotEmpty;

  Future<void> _addIngredient() async {
    final searchService = ref.read(foodSearchServiceProvider);
    final apiClient = ref.read(openFoodFactsClientProvider);
    final food = await showSearch<FoodSearchItem?>(
      context: context,
      delegate: FoodSearchDelegate(
        searchService: searchService,
        apiClient: apiClient,
        onCreateCustomFood: (context, {existingFood}) async {
          return await Navigator.of(context).push<Food>(
            MaterialPageRoute(
              builder: (_) => ManualFoodForm(existingFood: existingFood),
            ),
          );
        },
      ),
    );
    if (food == null || !mounted) return;

    final quantityStr = await showDialog<String>(
      context: context,
      builder: (ctx) => _QuantityDialog(
        foodName: food.name,
        unit: food.servingUnit,
        initialValue: _formatQuantity(food.servingQuantity),
      ),
    );
    if (quantityStr == null || !mounted) return;
    final quantity = double.tryParse(quantityStr) ?? 1;

    setState(() {
      _ingredients.add(IngredientWithFood(
        ingredient: RecipeIngredient(
          id: -1,
          recipeId: widget.recipeId ?? -1,
          foodId: food.localId ?? -1,
          quantity: quantity,
          createdAt: DateTime.now().toIso8601String(),
        ),
        food: Food(
          id: food.localId ?? -1,
          name: food.name,
          servingLabel: food.servingLabel,
          servingQuantity: food.servingQuantity,
          servingUnit: food.servingUnit,
          caloriesPerServing: food.caloriesPerServing,
          proteinPerServing: food.proteinPerServing,
          carbsPerServing: food.carbsPerServing,
          fatPerServing: food.fatPerServing,
          barcode: food.barcode,
          brand: food.brand,
          source: food.source,
          createdAt: '',
        ),
      ));
    });
  }

  Future<void> _editIngredient(int index) async {
    final item = _ingredients[index];
    final quantityStr = await showDialog<String>(
      context: context,
      builder: (ctx) => _QuantityDialog(
        foodName: item.food.name,
        unit: item.food.servingUnit,
        initialValue: _formatQuantity(item.ingredient.quantity),
      ),
    );
    if (quantityStr == null || !mounted) return;
    final quantity = double.tryParse(quantityStr) ?? 1;
    setState(() {
      _ingredients[index] = IngredientWithFood(
        ingredient: item.ingredient.copyWith(quantity: quantity),
        food: item.food,
      );
    });
  }

  String _formatQuantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  Future<void> _deleteIngredient(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove ingredient?'),
        content: Text('Remove "${_ingredients[index].food.name}" from the recipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _ingredients.removeAt(index));
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now().toIso8601String();
      final servingSize = double.tryParse(_servingSizeController.text) ?? 0;

      if (widget.recipeId != null) {
        await db.updateRecipe(
          widget.recipeId!,
          RecipesCompanion(
            name: Value(_nameController.text.trim()),
            servingSize: Value(servingSize),
            servingLabel: Value(_servingLabelController.text.trim()),
            updatedAt: Value(now),
          ),
        );
        await db.deleteIngredientsForRecipe(widget.recipeId!);
        for (final item in _ingredients) {
          await db.insertIngredient(RecipeIngredientsCompanion.insert(
            recipeId: widget.recipeId!,
            foodId: item.ingredient.foodId,
            quantity: item.ingredient.quantity,
            createdAt: now,
          ));
        }
      } else {
        final recipeId = await db.insertRecipe(RecipesCompanion.insert(
          name: _nameController.text.trim(),
          servingSize: servingSize,
          servingLabel: _servingLabelController.text.trim(),
          createdAt: now,
          updatedAt: now,
        ));

        for (final item in _ingredients) {
          await db.insertIngredient(RecipeIngredientsCompanion.insert(
            recipeId: recipeId,
            foodId: item.ingredient.foodId,
            quantity: item.ingredient.quantity,
            createdAt: now,
          ));
        }
      }

      if (mounted) {
        ref.invalidate(recipeListProvider);
        if (widget.recipeId != null) {
          ref.invalidate(recipeDetailProvider(widget.recipeId!));
        }
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save recipe: $e'),
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

  void _openLogSheet() {
    final asyncDetail = ref.read(recipeDetailProvider(widget.recipeId!));
    final detail = asyncDetail.asData?.value;
    if (detail == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogRecipeSheet(detail: detail),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isEdit = widget.recipeId != null;
    final servingSize = double.tryParse(_servingSizeController.text) ?? 0;
    final label = _servingLabelController.text.trim();

    double totalCals = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
    for (final item in _ingredients) {
      final qty = item.ingredient.quantity;
      final sq = item.food.servingQuantity > 0 ? item.food.servingQuantity : 1;
      totalCals += item.food.caloriesPerServing * (qty / sq);
      totalProtein += item.food.proteinPerServing * (qty / sq);
      totalCarbs += item.food.carbsPerServing * (qty / sq);
      totalFat += item.food.fatPerServing * (qty / sq);
    }
    final perUnit = servingSize > 0 ? servingSize : 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? _nameController.text : 'New Recipe'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.playlist_add_check),
              onPressed: _openLogSheet,
              tooltip: 'Log this recipe',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Recipe name'),
            enabled: !_readOnly,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _servingSizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Serving size'),
                  enabled: !_readOnly,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _servingLabelController,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  enabled: !_readOnly,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total: ${totalCals.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${totalFat.toStringAsFixed(1)}f · ${totalCarbs.toStringAsFixed(1)}c · ${totalProtein.toStringAsFixed(1)}p',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (servingSize > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Per $label: ${(totalCals / perUnit).toStringAsFixed(1)} kcal · ${(totalFat / perUnit).toStringAsFixed(1)}f · ${(totalCarbs / perUnit).toStringAsFixed(1)}c · ${(totalProtein / perUnit).toStringAsFixed(1)}p',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ingredients',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_ingredients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No ingredients yet. Tap + to add one.'),
            )
          else
            ..._ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return RecipeIngredientRow(
                item: item,
                onEdit: _readOnly ? null : () => _editIngredient(index),
                onDelete: _readOnly ? null : () => _deleteIngredient(index),
              );
            }),
          if (!_readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add),
                label: const Text('Add ingredient'),
              ),
            ),
          const SizedBox(height: 24),
          if (!_readOnly)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave && !_isSaving ? _save : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  final String foodName;
  final String unit;
  final String? initialValue;

  const _QuantityDialog({
    required this.foodName,
    required this.unit,
    this.initialValue,
  });

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '1');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Quantity for ${widget.foodName}'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Quantity in ${widget.unit}'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
