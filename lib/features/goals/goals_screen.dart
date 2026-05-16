import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/algorithms/mifflin_st_jeor.dart';
import '../../core/database/database.dart';
import '../../providers/bodyweight_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/unit_preferences_provider.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  String? _sex;
  String? _birthdate;
  final _heightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  bool _useImperial = false;
  int _activityLevel = 3;
  String _goalType = 'cut';
  final _calorieAdjustmentController = TextEditingController(text: '-500');
  double _proteinGPerLb = 1.0;
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
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _calorieAdjustmentController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    try {
      final db = ref.read(databaseProvider);
      final goals = await db.getGoals();
      if (goals != null && mounted) {
        setState(() {
          _sex = goals.sex;
          _birthdate = goals.birthdate;
          _useImperial = goals.useImperial == 1;
          if (_useImperial) {
            if (goals.heightCm != null) {
              final totalInches = _unitPrefs.displayHeight(goals.heightCm!);
              _heightFeetController.text = (totalInches ~/ 12).toString();
              _heightInchesController.text =
                  (totalInches % 12).round().toString();
            }
          } else {
            _heightController.text = goals.heightCm?.toString() ?? '';
          }
          _activityLevel = goals.activityLevel;
          _goalType = goals.goalType;
          _calorieAdjustmentController.text =
              goals.calorieAdjustment?.toStringAsFixed(0) ?? '-500';
          _proteinGPerLb = goals.proteinGPerLb;
          _fatCaloriePct = goals.fatCaloriePct;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSave {
    if (_sex == null) return false;
    if (_birthdate == null) return false;
    if (_useImperial) {
      if (_heightFeetController.text.trim().isEmpty) return false;
    } else {
      if (_heightController.text.trim().isEmpty) return false;
    }
    return true;
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

  String _fatGramPreview() {
    final weightKg = ref.read(bodyweightProvider).valueOrNull?.firstOrNull?.weightKg;
    if (weightKg == null) return '';
    if (_sex == null) return '';
    if (_birthdate == null) return '';
    final heightCm = _useImperial
        ? (_heightFeetController.text.isNotEmpty && _heightInchesController.text.isNotEmpty
            ? _unitPrefs.heightCm(
                double.tryParse(_heightFeetController.text)! * 12 +
                    double.tryParse(_heightInchesController.text)!)
            : null)
        : double.tryParse(_heightController.text);
    if (heightCm == null) return '';

    final maintenance = estimateMaintenance(
      sex: _sex!,
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
      } else if (!imperial && _useImperial) {
        final feet = double.tryParse(_heightFeetController.text);
        final inches = double.tryParse(_heightInchesController.text);
        if (feet != null && inches != null) {
          final heightCm = UnitPreferences.imperial().heightCm(feet * 12 + inches);
          _heightController.text = heightCm.toStringAsFixed(1);
        }
        _heightFeetController.clear();
        _heightInchesController.clear();
      }
      _useImperial = imperial;
    });
  }

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

    try {
      await db.upsertGoals(UserGoalsCompanion(
        goalType: Value(_goalType),
        calorieAdjustment: Value<double?>(
          double.tryParse(_calorieAdjustmentController.text),
        ),
        proteinGPerLb: Value(_proteinGPerLb),
        fatCaloriePct: Value(_fatCaloriePct),
        sex: Value(_sex),
        heightCm: Value(heightCm),
        birthdate: Value(_birthdate),
        useImperial: Value(_useImperial ? 1 : 0),
        activityLevel: Value(_activityLevel),
        updatedAt: Value(now),
      ));
      ref.invalidate(userGoalsProvider);

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals saved')),
        );
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
    ref.watch(bodyweightProvider);
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
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
              selected: _sex != null ? {_sex!} : {},
              emptySelectionAllowed: true,
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
                onTap: () => setState(() => _activityLevel = level.$1),
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
                helperText:
                    _ratePreview(_calorieAdjustmentController.text),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            _calorieWarning(_calorieAdjustmentController.text),
            const Divider(height: 32),
            Text(
              'Protein: ${_unitPrefs.displayProteinGPerLb(_proteinGPerLb).toStringAsFixed(1)} ${_unitPrefs.proteinUnit}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _unitPrefs.displayProteinGPerLb(_proteinGPerLb),
              min: _unitPrefs.displayProteinGPerLb(0.5),
              max: _unitPrefs.displayProteinGPerLb(2.0),
              divisions: 30,
              label: '${_unitPrefs.displayProteinGPerLb(_proteinGPerLb).toStringAsFixed(1)} ${_unitPrefs.proteinUnit}',
              onChanged: (v) => setState(() =>
                  _proteinGPerLb = _unitPrefs.proteinGPerLbFromDisplay(v)),
            ),
            Text(
              'Recommended: ${_unitPrefs.displayProteinGPerLb(0.8).toStringAsFixed(1)}\u2013${_unitPrefs.displayProteinGPerLb(1.4).toStringAsFixed(1)} ${_unitPrefs.proteinUnit}',
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
              _fatGramPreview(),
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
            Text(
              'Carbs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Fills remaining calories',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
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
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}
