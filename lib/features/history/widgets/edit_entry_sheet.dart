import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../providers/data_trigger_provider.dart';
import '../../../providers/food_log_provider.dart';

class EditEntrySheet extends ConsumerStatefulWidget {
  final FoodEntry entry;

  const EditEntrySheet({super.key, required this.entry});

  @override
  ConsumerState<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<EditEntrySheet> {
  late final TextEditingController _servingsController;
  late String _mealType;
  late String _entryName;
  bool _saving = false;

  late double _baseCalories;
  late double _baseProtein;
  late double _baseCarbs;
  late double _baseFat;
  bool _updatingFromServings = false;

  double _displayCalories = 0;
  double _displayProtein = 0;
  double _displayCarbs = 0;
  double _displayFat = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _entryName = e.name;
    _servingsController = TextEditingController(
        text: _formatQuantity(e.servings));
    _mealType = e.mealType;

    _baseCalories = e.calories / e.servings;
    _baseProtein = e.proteinGrams / e.servings;
    _baseCarbs = e.carbsGrams / e.servings;
    _baseFat = e.fatGrams / e.servings;

    _displayCalories = e.calories;
    _displayProtein = e.proteinGrams;
    _displayCarbs = e.carbsGrams;
    _displayFat = e.fatGrams;

    _servingsController.addListener(_onServingsChanged);
  }

  @override
  void dispose() {
    _servingsController.dispose();
    super.dispose();
  }

  void _onServingsChanged() {
    if (_updatingFromServings) return;
    final servings = double.tryParse(_servingsController.text);
    if (servings != null && servings > 0) {
      _updatingFromServings = true;
      setState(() {
        _displayCalories = _baseCalories * servings;
        _displayProtein = _baseProtein * servings;
        _displayCarbs = _baseCarbs * servings;
        _displayFat = _baseFat * servings;
      });
      _updatingFromServings = false;
    }
  }

  String _formatQuantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  bool get _isValid {
    final servings = double.tryParse(_servingsController.text);
    return servings != null && servings > 0;
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;

    setState(() => _saving = true);

    try {
      final entry = FoodEntry(
        id: widget.entry.id,
        name: _entryName,
        calories: _displayCalories,
        proteinGrams: _displayProtein,
        carbsGrams: _displayCarbs,
        fatGrams: _displayFat,
        servings: double.parse(_servingsController.text),
        servingLabel: widget.entry.servingLabel,
        barcode: widget.entry.barcode,
        foodId: widget.entry.foodId,
        recipeId: widget.entry.recipeId,
        mealType: _mealType,
        loggedAt: widget.entry.loggedAt,
      );
      await ref.read(foodLogProvider).updateEntry(entry);
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
    final theme = Theme.of(context);

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
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text('Name',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
                Expanded(child: Text(_entryName)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text('Quantity',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                child: TextField(
                  key: const Key('edit_servings_field'),
                  controller: _servingsController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    suffixText: widget.entry.servingLabel,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _macroRow(theme, 'Calories', _displayCalories.toStringAsFixed(0)),
          const SizedBox(height: 4),
          _macroRow(theme, 'Protein', '${_displayProtein.toStringAsFixed(1)} g'),
          const SizedBox(height: 4),
          _macroRow(theme, 'Carbs', '${_displayCarbs.toStringAsFixed(1)} g'),
          const SizedBox(height: 4),
          _macroRow(theme, 'Fat', '${_displayFat.toStringAsFixed(1)} g'),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text('Meal type',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(),
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

  Widget _macroRow(ThemeData theme, String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
