import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../providers/bodyweight_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/goals_provider.dart';
import '../../providers/macro_targets_provider.dart';
import '../settings/settings_screen.dart';
import 'widgets/bodyweight_sparkline.dart';
import 'widgets/macro_ring.dart';
import 'widgets/maintenance_card.dart';

final _dateFmt = DateFormat('MMMM d');

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(todaysFoodProvider);
    final targetsAsync = ref.watch(macroTargetsProvider);
    final weightsAsync = ref.watch(bodyweightProvider);
    final goalsAsync = ref.watch(userGoalsProvider);

    if (entriesAsync.isLoading ||
        targetsAsync.isLoading ||
        weightsAsync.isLoading ||
        goalsAsync.isLoading) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (entriesAsync.hasError ||
        targetsAsync.hasError ||
        weightsAsync.hasError ||
        goalsAsync.hasError) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: Center(
          child: Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final entries = entriesAsync.value ?? [];
    final targets = targetsAsync.value!;
    final weights = weightsAsync.value ?? [];
    final goals = goalsAsync.value;

    if (entries.isEmpty && weights.isEmpty && goals == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: _buildOnboarding(context),
      );
    }

    final consumedCals = entries.fold(0.0, (s, e) => s + e.calories);
    final consumedProtein = entries.fold(0.0, (s, e) => s + e.proteinGrams);
    final consumedFat = entries.fold(0.0, (s, e) => s + e.fatGrams);
    final consumedCarbs = entries.fold(0.0, (s, e) => s + e.carbsGrams);

    final latestWeight = weights.isNotEmpty ? weights.first.weightKg : null;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            if (goals?.goalWeightKg != null && latestWeight != null)
            _buildGoalWeightCard(
              context,
              currentKg: latestWeight,
              goalKg: goals!.goalWeightKg!,
              useImperial: goals.useImperial == 1,
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            child: MacroRing(
              consumed: consumedCals,
              target: targets.targetCalories,
              label: 'Calories',
              unit: 'kcal',
              color: Theme.of(context).colorScheme.primary,
              large: true,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: MacroRing(
                    consumed: consumedProtein,
                    target: targets.proteinGrams,
                    label: 'Protein',
                    unit: 'g',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MacroRing(
                    consumed: consumedFat,
                    target: targets.fatGrams,
                    label: 'Fat',
                    unit: 'g',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MacroRing(
                    consumed: consumedCarbs,
                    target: targets.carbsGrams,
                    label: 'Carbs',
                    unit: 'g',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (goals != null) _buildRateCard(context, goals),
          const SizedBox(height: 16),
          const MaintenanceCard(),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bodyweight',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          BodyweightSparkline(entries: weights),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Dashboard'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildOnboarding(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to bioloop',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log your first meal from one of the tabs below to get started.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Today, ${_dateFmt.format(DateTime.now())}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }

  Widget _buildGoalWeightCard(BuildContext context, {
    required double currentKg,
    required double goalKg,
    required bool useImperial,
  }) {
    final factor = useImperial ? 2.20462 : 1.0;
    final unit = useImperial ? 'lb' : 'kg';
    final current = currentKg * factor;
    final goal = goalKg * factor;
    final diff = (goal - current).abs();
    final isAtOrPastGoal = current >= goal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: isAtOrPastGoal
                  ? Text(
                      'You reached your goal!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                    )
                  : Text.rich(
                      TextSpan(
                        text: '${current.toStringAsFixed(0)} $unit',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: ' → ',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          TextSpan(
                            text: '${goal.toStringAsFixed(0)} $unit',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          WidgetSpan(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '(${diff.toStringAsFixed(0)} $unit to go)',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateCard(BuildContext context, UserGoal goals) {
    final adjustment = goals.calorieAdjustment ?? 0.0;
    if (adjustment == 0.0) {
      return _rateCard(context, 'Maintenance', Colors.grey);
    }

    final rateLbsPerWeek = (adjustment.abs() * 7) / 3500.0;
    final isLoss = adjustment < 0;

    final label = isLoss ? 'loss' : 'gain';
    final color = isLoss ? Colors.green : Colors.orange;

    String rateStr;
    if (rateLbsPerWeek < 0.3) {
      rateStr = '<0.5';
    } else {
      rateStr = rateLbsPerWeek.toStringAsFixed(1);
    }

    return _rateCard(
      context,
      '~$rateStr lb/week $label',
      color,
    );
  }

  Widget _rateCard(BuildContext context, String text, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.trending_flat, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
