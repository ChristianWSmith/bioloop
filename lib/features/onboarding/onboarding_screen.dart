import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/algorithms/mifflin_st_jeor.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/unit_preferences_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final bool _canPop = false;
  bool _saving = false;

  String _sex = 'male';
  String? _birthdate;
  final _heightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _weightController = TextEditingController();
  bool _useImperial = true;
  int _activityLevel = 3;
  String _goalType = 'maintain';
  final _calorieAdjustmentController = TextEditingController(text: '0');
  double _proteinGPerLb = 1.0;
  String _proteinBasis = 'bodyweight';
  double _fatCaloriePct = 25.0;

  UnitPreferences get _unitPrefs =>
      _useImperial ? UnitPreferences.imperial() : UnitPreferences.metric();

  static const _activityLevels = [
    (1, 'Sedentary', 'Little to no exercise, desk job'),
    (2, 'Lightly active', 'Light exercise 1\u20133 days/week'),
    (3, 'Moderately active', 'Moderate exercise 3\u20135 days/week'),
    (4, 'Active', 'Hard exercise 6\u20137 days/week'),
    (5, 'Extra active', 'Very hard exercise + physical job'),
  ];

  @override
  void dispose() {
    _heightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _calorieAdjustmentController.dispose();
    super.dispose();
  }

  String _formatRate(double value) {
    final s = value.toStringAsFixed(1);
    if (s.endsWith('.0')) return s.substring(0, s.length - 2);
    return s;
  }

  String _ratePreview(String adjustmentText) {
    final adjustment = double.tryParse(adjustmentText);
    if (adjustment == null) return '';
    final rate = adjustment * 7 / 3500;
    final absRate = _formatRate((rate * _unitPrefs.rateFactor).abs());
    if (rate < 0) return '~$absRate ${_unitPrefs.rateUnit} loss';
    if (rate > 0) return '~$absRate ${_unitPrefs.rateUnit} gain';
    return 'Maintenance';
  }

  Widget _calorieWarning(String text) {
    final adjustment = double.tryParse(text);
    if (adjustment == null) return const SizedBox.shrink();
    if (adjustment < -500) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Deficits over 500 kcal/day are aggressive. Consider a smaller deficit.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.tertiary,
            fontSize: 12,
          ),
        ),
      );
    }
    if (adjustment > 300) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Surpluses over 300 kcal/day may lead to excess fat gain. Consider a smaller surplus.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.tertiary,
            fontSize: 12,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _onGoalTypeChanged(String type) {
    setState(() {
      _goalType = type;
      if (type == 'cut') {
        _calorieAdjustmentController.text = '-500';
      } else if (type == 'maintain') {
        _calorieAdjustmentController.text = '0';
      } else {
        _calorieAdjustmentController.text = '300';
      }
    });
  }

  void _onUnitsChanged(bool imperial) {
    setState(() {
      if (imperial && !_useImperial) {
        final heightCm = double.tryParse(_heightController.text);
        if (heightCm != null && heightCm > 0) {
          final totalInches = UnitPreferences.imperial().displayHeight(heightCm);
          final feet = totalInches ~/ 12;
          final inches = (totalInches % 12).round();
          _heightFeetController.text = feet.toString();
          _heightInchesController.text = inches.toString();
        }
        _heightController.clear();

        final weightKg = double.tryParse(_weightController.text);
        if (weightKg != null && weightKg > 0) {
          _weightController.text = (weightKg * 2.20462).toStringAsFixed(2);
        }
      } else if (!imperial && _useImperial) {
        final feet = double.tryParse(_heightFeetController.text);
        final inches = double.tryParse(_heightInchesController.text);
        if (feet != null && inches != null) {
          final heightCm = UnitPreferences.imperial().heightCm(feet * 12 + inches);
          _heightController.text = heightCm.toStringAsFixed(2);
        }
        _heightFeetController.clear();
        _heightInchesController.clear();

        final weightLb = double.tryParse(_weightController.text);
        if (weightLb != null && weightLb > 0) {
          _weightController.text = (weightLb / 2.20462).toStringAsFixed(2);
        }
      }
      _useImperial = imperial;
    });
  }

  bool get _canSave =>
      _birthdate != null &&
      (_useImperial
          ? _heightFeetController.text.isNotEmpty
          : _heightController.text.isNotEmpty) &&
      _weightController.text.isNotEmpty;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final now = DateTime.now().toIso8601String();
    final db = ref.read(databaseProvider);

    final heightCm = _useImperial
        ? _unitPrefs.heightCm(
            double.parse(_heightFeetController.text) * 12 +
                (double.tryParse(_heightInchesController.text) ?? 0))
        : double.parse(_heightController.text);

    final weightKg = _useImperial
        ? double.parse(_weightController.text) / 2.20462
        : double.parse(_weightController.text);

    try {
      await db.upsertGoals(UserGoalsCompanion(
        goalType: Value(_goalType),
        calorieAdjustment: Value<double?>(
          double.tryParse(_calorieAdjustmentController.text),
        ),
        proteinGPerLb: Value(_proteinGPerLb),
        proteinBasis: Value(_proteinBasis),
        fatCaloriePct: Value(_fatCaloriePct),
        sex: Value(_sex),
        heightCm: Value(heightCm),
        birthdate: Value(_birthdate),
        useImperial: Value(_useImperial ? 1 : 0),
        activityLevel: Value(_activityLevel),
        onboardingCompleted: const Value(1),
        updatedAt: Value(now),
      ));

      await db.insertWeight(BodyweightEntriesCompanion.insert(
        weightKg: weightKg,
        loggedAt: DateTime.now().toIso8601String(),
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

  String _onboardingFatGramPreview() {
    final weightText = _weightController.text;
    final rawWeight = double.tryParse(weightText);
    if (rawWeight == null || rawWeight <= 0) return '';
    if (_birthdate == null) return '';
    final heightCm = _useImperial
        ? _unitPrefs.heightCm(
            (double.tryParse(_heightFeetController.text) ?? 0) * 12 +
                (double.tryParse(_heightInchesController.text) ?? 0))
        : double.tryParse(_heightController.text);
    if (heightCm == null || heightCm <= 0) return '';

    final weightKg = _useImperial ? rawWeight / 2.20462 : rawWeight;
    final maintenance = estimateMaintenance(
      sex: _sex,
      weightKg: weightKg,
      heightCm: heightCm,
      birthdate: _birthdate,
      activityLevel: _activityLevel,
    );
    final adjustment = double.tryParse(_calorieAdjustmentController.text) ?? 0;
    final targetCals = maintenance + adjustment;
    final fatCals = targetCals * (_fatCaloriePct / 100);
    final fatGrams = fatCals / 9;
    return '${_fatCaloriePct.toStringAsFixed(0)}% = ${fatGrams.toStringAsFixed(0)}g';
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
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
      SystemNavigator.pop();
    }
  }

  Widget _buildHeightField() {
    if (_useImperial) {
      return Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _heightFeetController,
              decoration: const InputDecoration(
                labelText: 'Height (ft)',
                hintText: 'e.g. 5',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Invalid';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _heightInchesController,
              decoration: const InputDecoration(
                labelText: 'Height (in)',
                hintText: 'e.g. 10',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      );
    }
    return TextFormField(
      controller: _heightController,
      decoration: const InputDecoration(
        labelText: 'Height',
        hintText: 'e.g. 175',
        suffixText: 'cm',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        final n = double.tryParse(v);
        if (n == null || n <= 0) return 'Enter a valid height';
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
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
              _sectionTitle(context, 'Profile'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'male', label: Text('Male')),
                  ButtonSegment(value: 'female', label: Text('Female')),
                ],
                selected: {_sex},
                onSelectionChanged: (v) => setState(() => _sex = v.first),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Birthdate'),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _birthdate ?? 'Select your birthdate',
                    style: TextStyle(
                      color: _birthdate != null
                          ? null
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      initialDate: now.subtract(const Duration(days: 365 * 25)),
                      firstDate: now.subtract(const Duration(days: 365 * 120)),
                      lastDate: now.subtract(const Duration(days: 365 * 12)),
                    );
                    if (date != null) {
                      setState(() {
                        _birthdate =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
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
                onSelectionChanged: (v) => _onUnitsChanged(v.first),
              ),
              const SizedBox(height: 12),
              _buildHeightField(),
              const Divider(height: 32),
              _sectionTitle(context, 'Starting Weight'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _weightController,
                decoration: InputDecoration(
                  labelText: 'Weight',
                  hintText: _useImperial ? 'e.g. 165' : 'e.g. 75',
                  suffixText: _useImperial ? 'lb' : 'kg',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid weight';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const Divider(height: 32),
              _sectionTitle(context, 'Activity Level'),
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
              _sectionTitle(context, 'Goal Type'),
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
                onSelectionChanged: (v) => _onGoalTypeChanged(v.first),
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
              _calorieWarning(_calorieAdjustmentController.text),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'bodyweight', label: Text('Per ${_useImperial ? "lb" : "kg"} bodyweight')),
                  ButtonSegment(value: 'height', label: Text('Per cm height')),
                ],
                selected: {_proteinBasis},
                onSelectionChanged: (v) => setState(() => _proteinBasis = v.first),
              ),
              const SizedBox(height: 12),
              Text(
                'Protein: ${_unitPrefs.displayProteinGPerLb(_proteinGPerLb).toStringAsFixed(1)} ${_unitPrefs.proteinUnitForBasis(_proteinBasis)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: _unitPrefs.displayProteinGPerLb(_proteinGPerLb),
                min: _unitPrefs.displayProteinGPerLb(0.5),
                max: _unitPrefs.displayProteinGPerLb(2.0),
                divisions: 30,
                label: '${_unitPrefs.displayProteinGPerLb(_proteinGPerLb).toStringAsFixed(1)} ${_unitPrefs.proteinUnitForBasis(_proteinBasis)}',
                onChanged: (v) => setState(() =>
                    _proteinGPerLb = _unitPrefs.proteinGPerLbFromDisplay(v)),
              ),
              Text(
                _proteinBasis == 'bodyweight'
                    ? 'Recommended: ${_unitPrefs.displayProteinGPerLb(0.8).toStringAsFixed(1)}\u2013${_unitPrefs.displayProteinGPerLb(1.4).toStringAsFixed(1)} ${_unitPrefs.proteinUnitForBasis(_proteinBasis)}'
                    : 'Recommended: 0.8\u20131.4 ${_unitPrefs.proteinUnitForBasis(_proteinBasis)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Fat: ${_fatCaloriePct.toStringAsFixed(0)}% of calories',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _onboardingFatGramPreview(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Slider(
                value: _fatCaloriePct,
                min: 10,
                max: 50,
                divisions: 40,
                label: '${_fatCaloriePct.toStringAsFixed(0)}%',
                onChanged: (v) => setState(() => _fatCaloriePct = v),
              ),
              Text(
                'Recommended: 20\u201335% of calories',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle(context, 'Carbs'),
              const SizedBox(height: 4),
              Text(
                'Fills remaining calories',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (!_canSave || _saving) ? null : _save,
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
