import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _canPop = false;
  bool _saving = false;

  String? _sex;
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime _weightDate = DateTime.now();
  final _goalWeightController = TextEditingController();
  bool _useImperial = false;
  int _activityLevel = 3;
  String _goalType = 'cut';
  final _calorieAdjustmentController = TextEditingController(text: '-500');
  double _proteinGPerLb = 1.0;
  double _fatCaloriePct = 25.0;

  static const _activityLevels = [
    (1, 'Sedentary', 'Little to no exercise, desk job'),
    (2, 'Lightly active', 'Light exercise 1\u20133 days/week'),
    (3, 'Moderately active', 'Moderate exercise 3\u20135 days/week'),
    (4, 'Active', 'Hard exercise 6\u20137 days/week'),
    (5, 'Extra active', 'Very hard exercise + physical job'),
  ];

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalWeightController.dispose();
    _calorieAdjustmentController.dispose();
    super.dispose();
  }

  String _ratePreview(String adjustmentText) {
    final adjustment = double.tryParse(adjustmentText);
    if (adjustment == null) return '';
    final rate = adjustment * 7 / 3500;
    final absRate = rate.abs().toStringAsFixed(1);
    if (rate < 0) return '~$absRate lb/week loss';
    if (rate > 0) return '~$absRate lb/week gain';
    return 'Maintenance';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your sex')),
      );
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now().toIso8601String();
    final db = ref.read(databaseProvider);

    try {
      await db.upsertGoals(UserGoalsCompanion(
        goalType: Value(_goalType),
        calorieAdjustment: Value<double?>(
          double.tryParse(_calorieAdjustmentController.text),
        ),
        proteinGPerLb: Value(_proteinGPerLb),
        fatCaloriePct: Value(_fatCaloriePct),
        sex: Value(_sex),
        heightCm: Value(double.parse(_heightController.text)),
        age: Value(int.parse(_ageController.text)),
        goalWeightKg: _goalWeightController.text.isNotEmpty
            ? Value<double?>(double.parse(_goalWeightController.text))
            : const Value<double?>(null),
        useImperial: Value(_useImperial ? 1 : 0),
        activityLevel: Value(_activityLevel),
        onboardingCompleted: const Value(1),
        updatedAt: Value(now),
      ));

      await db.insertWeight(BodyweightEntriesCompanion.insert(
        weightKg: double.parse(_weightController.text),
        loggedAt: _weightDate.toIso8601String(),
      ));

      if (mounted) {
        widget.onComplete();
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

  Future<void> _showDiscardDialog() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard progress?'),
        content: const Text('Your progress won\'t be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldPop == true && mounted) {
      setState(() => _canPop = true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showDiscardDialog();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Setup')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Personal Info',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'male', label: Text('Male')),
                  ButtonSegment(value: 'female', label: Text('Female')),
                ],
                selected: _sex != null ? {_sex!} : {},
                emptySelectionAllowed: true,
                onSelectionChanged: (v) => setState(() => _sex = v.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  hintText: 'e.g. 25',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid age';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Height',
                  hintText: 'e.g. 175',
                  suffixText: 'cm',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid height';
                  return null;
                },
              ),
              const Divider(height: 32),
              Text('Starting Weight',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  hintText: 'e.g. 75',
                  suffixText: 'kg',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid weight';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${_weightDate.year}-'
                    '${_weightDate.month.toString().padLeft(2, '0')}-'
                    '${_weightDate.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _weightDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _weightDate = date);
                    }
                  },
                ),
              ),
              const Divider(height: 32),
              Text('Preferences',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _goalWeightController,
                decoration: const InputDecoration(
                  labelText: 'Goal weight (optional)',
                  hintText: 'e.g. 70',
                  suffixText: 'kg',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid weight';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Metric'),
                    tooltip: 'kg, cm',
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Imperial'),
                    tooltip: 'lb, ft/in',
                  ),
                ],
                selected: {_useImperial},
                onSelectionChanged: (v) =>
                    setState(() => _useImperial = v.first),
              ),
              const Divider(height: 32),
              Text('Activity Level',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              ..._activityLevels.map(
                (level) => ListTile(
                  leading: Icon(
                    _activityLevel == level.$1
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(level.$2),
                  subtitle: Text(level.$3),
                  selected: _activityLevel == level.$1,
                  contentPadding: EdgeInsets.zero,
                  onTap: () =>
                      setState(() => _activityLevel = level.$1),
                ),
              ),
              const Divider(height: 32),
              Text('Initial Goals',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'cut',
                    label: Text('Cut'),
                    tooltip: 'Default: -500 kcal',
                  ),
                  ButtonSegment(
                    value: 'maintain',
                    label: Text('Maintain'),
                    tooltip: 'Default: 0 kcal',
                  ),
                  ButtonSegment(
                    value: 'bulk',
                    label: Text('Bulk'),
                    tooltip: 'Default: +300 kcal',
                  ),
                ],
                selected: {_goalType},
                onSelectionChanged: (v) {
                  setState(() {
                    _goalType = v.first;
                    if (_goalType == 'cut') {
                      _calorieAdjustmentController.text = '-500';
                    } else if (_goalType == 'maintain') {
                      _calorieAdjustmentController.text = '0';
                    } else {
                      _calorieAdjustmentController.text = '300';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _calorieAdjustmentController,
                decoration: InputDecoration(
                  labelText: 'Calorie adjustment',
                  helperText: _ratePreview(
                    _calorieAdjustmentController.text,
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'Protein: ${_proteinGPerLb.toStringAsFixed(1)} g/lb',
              ),
              Slider(
                value: _proteinGPerLb,
                min: 0.5,
                max: 2.0,
                divisions: 30,
                label: '${_proteinGPerLb.toStringAsFixed(1)} g/lb',
                onChanged: (v) => setState(() => _proteinGPerLb = v),
              ),
              const SizedBox(height: 12),
              Text(
                'Fat: ${_fatCaloriePct.toStringAsFixed(0)}% of calories',
              ),
              Slider(
                value: _fatCaloriePct,
                min: 10,
                max: 50,
                divisions: 40,
                label: '${_fatCaloriePct.toStringAsFixed(0)}%',
                onChanged: (v) => setState(() => _fatCaloriePct = v),
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
      ),
    );
  }
}
