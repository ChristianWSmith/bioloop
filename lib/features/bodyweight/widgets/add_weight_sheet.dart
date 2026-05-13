import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../providers/bodyweight_provider.dart';
import '../../../providers/unit_preferences_provider.dart';

class AddWeightSheet extends ConsumerStatefulWidget {
  final BodyweightEntry? entry;

  const AddWeightSheet({super.key, this.entry});

  @override
  ConsumerState<AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends ConsumerState<AddWeightSheet> {
  final _weightController = TextEditingController();
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      final prefs = ref.read(unitPreferencesProvider);
      _weightController.text = prefs.displayWeight(widget.entry!.weightKg).toStringAsFixed(2);
      _selectedDate = DateTime.parse(widget.entry!.loggedAt);
    } else {
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
    }
    _weightController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final text = _weightController.text.trim();
    if (text.isEmpty) return false;
    final value = double.tryParse(text);
    return value != null && value > 0;
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;

    setState(() => _saving = true);

    try {
      final service = ref.read(bodyweightServiceProvider);
      final prefs = ref.read(unitPreferencesProvider);
      final loggedAt =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final weightKg = prefs.kgWeight(double.parse(_weightController.text.trim()));

      if (widget.entry != null) {
        await service.updateWeight(BodyweightEntry(
          id: widget.entry!.id,
          weightKg: weightKg,
          loggedAt: loggedAt,
        ));
      } else {
        await service.insertWeight(BodyweightEntriesCompanion.insert(
          weightKg: weightKg,
          loggedAt: loggedAt,
        ));
      }

      if (mounted) {
        Navigator.of(context).pop();
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    final prefs = ref.watch(unitPreferencesProvider);

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
            isEdit ? 'Edit weight' : 'Log weight',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightController,
            decoration: InputDecoration(
              labelText: 'Weight',
              suffixText: prefs.weightUnit,
              errorText: _weightController.text.isNotEmpty && !_isValid
                  ? 'Enter a valid weight'
                  : null,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save_weight_button'),
            onPressed: _isValid && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEdit ? 'Update' : 'Log weight'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
