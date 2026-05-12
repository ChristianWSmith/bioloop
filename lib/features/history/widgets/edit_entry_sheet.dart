import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../providers/food_log_provider.dart';

class EditEntrySheet extends ConsumerStatefulWidget {
  final FoodEntry entry;

  const EditEntrySheet({super.key, required this.entry});

  @override
  ConsumerState<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<EditEntrySheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _servingsController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late String _mealType;
  bool _saving = false;

  late double _baseCalories;
  late double _baseProtein;
  late double _baseCarbs;
  late double _baseFat;
  bool _updatingFromServings = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _nameController = TextEditingController(text: e.name);
    _servingsController = TextEditingController(text: e.servings.toString());
    _caloriesController = TextEditingController(text: e.calories.toString());
    _proteinController = TextEditingController(text: e.proteinGrams.toString());
    _carbsController = TextEditingController(text: e.carbsGrams.toString());
    _fatController = TextEditingController(text: e.fatGrams.toString());
    _mealType = e.mealType;

    _baseCalories = e.calories / e.servings;
    _baseProtein = e.proteinGrams / e.servings;
    _baseCarbs = e.carbsGrams / e.servings;
    _baseFat = e.fatGrams / e.servings;

    _servingsController.addListener(_onServingsChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _onServingsChanged() {
    if (_updatingFromServings) return;
    final servings = double.tryParse(_servingsController.text);
    if (servings != null && servings > 0) {
      _updatingFromServings = true;
      _caloriesController.text = (_baseCalories * servings).toStringAsFixed(1);
      _proteinController.text = (_baseProtein * servings).toStringAsFixed(1);
      _carbsController.text = (_baseCarbs * servings).toStringAsFixed(1);
      _fatController.text = (_baseFat * servings).toStringAsFixed(1);
      _updatingFromServings = false;
    }
  }

  bool get _isValid {
    if (_nameController.text.trim().isEmpty) return false;
    final servings = double.tryParse(_servingsController.text);
    if (servings == null || servings <= 0) return false;
    if (double.tryParse(_caloriesController.text) == null) return false;
    if (double.tryParse(_proteinController.text) == null) return false;
    if (double.tryParse(_carbsController.text) == null) return false;
    if (double.tryParse(_fatController.text) == null) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;

    setState(() => _saving = true);

    try {
      final entry = FoodEntry(
        id: widget.entry.id,
        name: _nameController.text.trim(),
        calories: double.parse(_caloriesController.text),
        proteinGrams: double.parse(_proteinController.text),
        carbsGrams: double.parse(_carbsController.text),
        fatGrams: double.parse(_fatController.text),
        servings: double.parse(_servingsController.text),
        servingLabel: widget.entry.servingLabel,
        barcode: widget.entry.barcode,
        foodId: widget.entry.foodId,
        recipeId: widget.entry.recipeId,
        mealType: _mealType,
        loggedAt: widget.entry.loggedAt,
      );
      await ref.read(foodLogProvider).updateEntry(entry);

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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit entry',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit_name_field'),
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('edit_servings_field'),
            controller: _servingsController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Servings',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caloriesController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Calories'),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _proteinController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _carbsController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fatController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Meal type'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _mealType,
                      isDense: true,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _mealType = v);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                            value: 'breakfast', child: Text('Breakfast')),
                        DropdownMenuItem(
                            value: 'lunch', child: Text('Lunch')),
                        DropdownMenuItem(
                            value: 'dinner', child: Text('Dinner')),
                        DropdownMenuItem(
                            value: 'snack', child: Text('Snack')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save_edit_button'),
            onPressed: _isValid && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
