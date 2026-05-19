import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../providers/data_trigger_provider.dart';
import '../../../providers/database_provider.dart';

const _commonUnits = [
  'g', 'ml', 'fl oz', 'oz', 'cups', 'tbsp', 'tsp',
  'slices', 'pieces', 'bars', 'servings',
];

class ManualFoodForm extends ConsumerStatefulWidget {
  final Food? existingFood;

  const ManualFoodForm({super.key, this.existingFood});

  @override
  ConsumerState<ManualFoodForm> createState() => _ManualFoodFormState();
}

class _ManualFoodFormState extends ConsumerState<ManualFoodForm> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _selectedUnit = 'g';
  String? _customUnit;

  @override
  void initState() {
    super.initState();
    if (widget.existingFood != null) {
      final food = widget.existingFood!;
      _nameController.text = food.name;
      _brandController.text = food.brand ?? '';
      _qtyController.text = _formatQuantity(food.servingQuantity);
      _caloriesController.text = _formatMacro(food.caloriesPerServing, 0);
      _proteinController.text = _formatMacro(food.proteinPerServing, 1);
      _carbsController.text = _formatMacro(food.carbsPerServing, 1);
      _fatController.text = _formatMacro(food.fatPerServing, 1);
      _selectedUnit = food.servingUnit;
      if (!_commonUnits.contains(food.servingUnit)) {
        _customUnit = food.servingUnit;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _qtyController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  String get _unit => _customUnit ?? _selectedUnit;

  bool get _unitIsCommon => _commonUnits.contains(_unit);

  String _formatQuantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  String _formatMacro(double value, int decimals) =>
      value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(decimals);

  String _buildLabel() {
    final qty = double.tryParse(_qtyController.text) ?? 1;
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
    return '$qtyStr $_unit';
  }

  Future<void> _openCustomUnitDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom unit'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Unit name',
            hintText: 'e.g. portions, packets',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _customUnit = result);
    }
  }

  void _autoComputeCalories() {
    final pText = _proteinController.text;
    final cText = _carbsController.text;
    final fText = _fatController.text;
    final p = double.tryParse(pText);
    final c = double.tryParse(cText);
    final f = double.tryParse(fText);
    final allZero =
        (p == null || p == 0) && (c == null || c == 0) && (f == null || f == 0);
    if (allZero) {
      return;
    }
    if (p == null || c == null || f == null) return;
    if (p < 0 || c < 0 || f < 0) return;
    final computed = (p * 4) + (c * 4) + (f * 9);
    final text = computed == computed.roundToDouble()
        ? computed.toInt().toString()
        : computed.toStringAsFixed(1);
    _caloriesController.text = text;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    final now = DateTime.now().toIso8601String();
    final qty = double.tryParse(_qtyController.text) ?? 1;

    try {
      final servingLabel = _buildLabel();
      final brand = _brandController.text.trim();
      final brandValue = brand.isEmpty ? null : brand;

      if (widget.existingFood != null && widget.existingFood!.id > 0) {
        await db.updateFoodById(widget.existingFood!.id, FoodsCompanion(
          name: Value(_nameController.text.trim()),
          servingLabel: Value(servingLabel),
          servingQuantity: Value(qty),
          servingUnit: Value(_unit),
          caloriesPerServing: Value(double.parse(_caloriesController.text)),
          proteinPerServing: Value(double.parse(_proteinController.text)),
          carbsPerServing: Value(double.parse(_carbsController.text)),
          fatPerServing: Value(double.parse(_fatController.text)),
          brand: Value(brandValue),
        ));

        if (mounted) {
          final food = Food(
            id: widget.existingFood!.id,
            name: _nameController.text.trim(),
            servingLabel: servingLabel,
            servingQuantity: qty,
            servingUnit: _unit,
            caloriesPerServing: double.parse(_caloriesController.text),
            proteinPerServing: double.parse(_proteinController.text),
            carbsPerServing: double.parse(_carbsController.text),
            fatPerServing: double.parse(_fatController.text),
            barcode: widget.existingFood!.barcode,
            brand: brandValue,
            source: widget.existingFood!.source,
            createdAt: widget.existingFood!.createdAt,
          );
          Navigator.of(context).pop(food);
        }
      } else {
        final id = await db.insertFood(FoodsCompanion.insert(
          name: _nameController.text.trim(),
          servingLabel: servingLabel,
          servingQuantity: Value(qty),
          servingUnit: Value(_unit),
          caloriesPerServing: double.parse(_caloriesController.text),
          proteinPerServing: double.parse(_proteinController.text),
          carbsPerServing: double.parse(_carbsController.text),
          fatPerServing: double.parse(_fatController.text),
          barcode: Value(widget.existingFood?.barcode),
          brand: Value(brandValue),
          source: Value(widget.existingFood?.source ?? 'manual'),
          createdAt: now,
        ));
        ref.read(dataTriggerProvider.notifier).state++;

        if (mounted) {
          final food = Food(
            id: id,
            name: _nameController.text.trim(),
            servingLabel: servingLabel,
            servingQuantity: qty,
            servingUnit: _unit,
            caloriesPerServing: double.parse(_caloriesController.text),
            proteinPerServing: double.parse(_proteinController.text),
            carbsPerServing: double.parse(_carbsController.text),
            fatPerServing: double.parse(_fatController.text),
            barcode: widget.existingFood?.barcode,
            brand: brandValue,
            source: widget.existingFood?.source ?? 'manual',
            createdAt: now,
          );
          Navigator.of(context).pop(food);
        }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingFood != null ? 'Edit Food' : 'Custom Food'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Chicken Breast',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Brand (optional)',
                hintText: 'e.g. Quaker',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _qtyController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _unitIsCommon ? _selectedUnit : null,
                        isDense: true,
                        hint: Text(_unit),
                        onChanged: (v) {
                          if (v == '__custom__') {
                            _openCustomUnitDialog();
                          } else if (v != null) {
                            setState(() {
                              _selectedUnit = v;
                              _customUnit = null;
                            });
                          }
                        },
                        items: [
                          ..._commonUnits.map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u),
                              )),
                          const DropdownMenuItem(
                            value: '__custom__',
                            child: Text('Custom\u2026'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Label: ${_buildLabel()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _caloriesController,
              decoration: const InputDecoration(
                labelText: 'Calories per serving',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {},
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fatController,
              decoration: const InputDecoration(
                labelText: 'Fat per serving (g)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _autoComputeCalories(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _carbsController,
              decoration: const InputDecoration(
                labelText: 'Carbs per serving (g)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _autoComputeCalories(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _proteinController,
              decoration: const InputDecoration(
                labelText: 'Protein per serving (g)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _autoComputeCalories(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
