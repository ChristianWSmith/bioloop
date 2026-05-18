import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../providers/bodyweight_provider.dart';
import '../../providers/data_trigger_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/unit_preferences_provider.dart';
import '../history/export.dart';
import 'widgets/add_weight_sheet.dart';

class BodyweightScreen extends ConsumerWidget {
  const BodyweightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightsAsync = ref.watch(bodyweightProvider);
    final prefs = ref.watch(unitPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bodyweight'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              final db = ref.read(databaseProvider);
              final entries =
                  await db.select(db.bodyweightEntries).get();
              if (!context.mounted) return;
              final csv = exportBodyweightToCsv(entries, weightUnit: prefs.weightUnit);
              if (value == 'share_weight') {
                await shareCsv(csv, 'bodyweight.csv');
              } else if (value == 'save_weight') {
                final path = await saveCsvToDownloads(
                  csv,
                  'bodyweight.csv',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved to $path')),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'share_weight',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'save_weight',
                child: ListTile(
                  leading: Icon(Icons.save_alt),
                  title: Text('Save to device'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('log_weight_button'),
        onPressed: () => _showSheet(context, ref),
        tooltip: 'Log weight',
        child: const Icon(Icons.add),
      ),
      body: weightsAsync.when(
        data: (weights) => weights.isEmpty
            ? const Center(child: Text('No entries yet'))
            : ListView.builder(
                itemCount: weights.length,
                itemBuilder: (ctx, i) =>
                    _buildEntry(context, ref, prefs, weights[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, WidgetRef ref,
      UnitPreferences prefs, BodyweightEntry entry) {
    final date = DateTime.parse(entry.loggedAt);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final displayWeight = prefs.displayWeight(entry.weightKg).toStringAsFixed(2);

    return ListTile(
      title: Text('$displayWeight ${prefs.weightUnit}'),
      subtitle: Text(dateStr),
      onTap: () => _showSheet(context, ref, entry: entry),
      onLongPress: () => _confirmDelete(context, ref, entry),
    );
  }

  Future<void> _showSheet(BuildContext context, WidgetRef ref,
      {BodyweightEntry? entry}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddWeightSheet(entry: entry),
    );
    ref.invalidate(bodyweightProvider);
    ref.read(dataTriggerProvider.notifier).state++;
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, BodyweightEntry entry) async {
    final prefs = ref.read(unitPreferencesProvider);
    final displayWeight = prefs.displayWeight(entry.weightKg).toStringAsFixed(2);
    final date = DateTime.parse(entry.loggedAt);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
            'Delete weight $displayWeight ${prefs.weightUnit} from $dateStr?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(bodyweightServiceProvider).deleteWeight(entry.id);
        ref.invalidate(bodyweightProvider);
        ref.read(dataTriggerProvider.notifier).state++;
      } catch (e) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to delete: $e'),
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
  }
}
