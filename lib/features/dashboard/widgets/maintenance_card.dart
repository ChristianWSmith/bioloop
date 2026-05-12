import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/algorithms/maintenance_calculator.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/maintenance_provider.dart';

final _kcalFmt = NumberFormat('#,###');

final _countDataDaysProvider = FutureProvider<int>((ref) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 30));
  final cutoffStr =
      '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

  final foods = await db.getEntriesPaginated(limit: 365);
  final weights = await db.getWeights();

  final foodDates = foods
      .map((e) => e.loggedAt.substring(0, 10))
      .where((d) => d.compareTo(cutoffStr) >= 0)
      .toSet();

  final weightDates = weights
      .map((e) => e.loggedAt.substring(0, 10))
      .where((d) => d.compareTo(cutoffStr) >= 0)
      .toSet();

  return foodDates.intersection(weightDates).length;
});

class MaintenanceCard extends ConsumerWidget {
  const MaintenanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenanceAsync = ref.watch(maintenanceProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: maintenanceAsync.when(
          loading: () => _buildLoading(),
          error: (_, _) => _buildError(),
          data: (result) {
            if (result == null) {
              return _buildInsufficientData(context, ref);
            }
            return _buildResult(result, theme);
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _shimmer(160, 20),
        const SizedBox(height: 8),
        _shimmer(100, 14),
      ],
    );
  }

  Widget _shimmer(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildInsufficientData(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(_countDataDaysProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maintenance Calories',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Log 14+ days of food + weight to calculate your maintenance',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        countAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 8),
          error: (_, _) => const LinearProgressIndicator(minHeight: 8),
          data: (count) {
            final progress = (count / 14.0).clamp(0.0, 1.0);
            return Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count/14',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maintenance Calories',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Unable to calculate — inconsistent data',
          style: TextStyle(fontSize: 13, color: Colors.red),
        ),
      ],
    );
  }

  Widget _buildResult(MaintenanceResult result, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maintenance Calories',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: 'Your maintenance: ',
            style: const TextStyle(fontSize: 14),
            children: [
              TextSpan(
                text:
                    '${_kcalFmt.format(result.maintenanceCalories.round())} kcal',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text:
                    ' (±${_kcalFmt.format(result.confidenceInterval.round())})',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Based on ${result.dataPoints} data points',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
