import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../providers/database_provider.dart';

class ManualFoodForm extends ConsumerStatefulWidget {
  const ManualFoodForm({super.key});

  @override
  ConsumerState<ManualFoodForm> createState() => _ManualFoodFormState();
}

class _ManualFoodFormState extends ConsumerState<ManualFoodForm> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _nameController = TextEditingController();
  final _servingLabelController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _servingSizeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _servingLabelController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingSizeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    final now = DateTime.now().toIso8601String();

    try {
      final id = await db.insertFood(FoodsCompanion.insert(
        name: _nameController.text.trim(),
        servingLabel: _servingLabelController.text.trim(),
        servingSizeGrams: _servingSizeController.text.isNotEmpty
            ? Value(double.parse(_servingSizeController.text))
            : const Value(null),
        servingQuantity: const Value.absent(),
        servingUnit: const Value.absent(),
        caloriesPerServing: double.parse(_caloriesController.text),
        proteinPerServing: double.parse(_proteinController.text),
        carbsPerServing: double.parse(_carbsController.text),
        fatPerServing: double.parse(_fatController.text),
        barcode: const Value(null),
        source: const Value('manual'),
        createdAt: now,
      ));

      if (mounted) {
        final food = Food(
          id: id,
          name: _nameController.text.trim(),
          servingLabel: _servingLabelController.text.trim(),
          servingSizeGrams: _servingSizeController.text.isNotEmpty
              ? double.parse(_servingSizeController.text)
              : null,
          servingQuantity: 1.0,
          servingUnit: 'serving',
          caloriesPerServing: double.parse(_caloriesController.text),
          proteinPerServing: double.parse(_proteinController.text),
          carbsPerServing: double.parse(_carbsController.text),
          fatPerServing: double.parse(_fatController.text),
          barcode: null,
          source: 'manual',
          createdAt: now,
        );
        Navigator.of(context).pop(food);
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
      appBar: AppBar(title: const Text('Custom Food')),
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
              controller: _servingLabelController,
              decoration: const InputDecoration(
                labelText: 'Serving label',
                hintText: 'e.g. 1 cup, 1 slice',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _caloriesController,
              decoration: const InputDecoration(
                labelText: 'Calories per serving',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _servingSizeController,
              decoration: const InputDecoration(
                labelText: 'Serving size in grams (optional)',
                hintText: 'e.g. 100',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
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
