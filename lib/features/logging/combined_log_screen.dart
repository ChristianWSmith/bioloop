import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../providers/data_trigger_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/food_search_provider.dart';
import '../../providers/macro_targets_provider.dart';
import '../history/export.dart';
import '../history/widgets/edit_entry_sheet.dart';
import '../recipes/recipe_list_screen.dart';
import 'widgets/day_navigator.dart';
import 'widgets/food_search_delegate.dart';
import 'widgets/macro_bars.dart';
import 'widgets/manual_food_form.dart';
import 'widgets/quick_food_log_sheet.dart';

class CombinedLogScreen extends ConsumerStatefulWidget {
  const CombinedLogScreen({super.key});

  @override
  ConsumerState<CombinedLogScreen> createState() => _CombinedLogScreenState();
}

class _CombinedLogScreenState extends ConsumerState<CombinedLogScreen> {
  late DateTime _currentDate;
  bool _pendingCreateCustom = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentDate = DateTime(now.year, now.month, now.day);
  }

  void _goToDate(DateTime date) {
    setState(() => _currentDate = DateTime(date.year, date.month, date.day));
  }

  Future<void> _onSearch() async {
    final searchService = ref.read(foodSearchServiceProvider);
    final apiClient = ref.read(openFoodFactsClientProvider);
    final result = await showSearch<FoodSearchItem?>(
      context: context,
      delegate: FoodSearchDelegate(
        searchService: searchService,
        apiClient: apiClient,
        onCreateCustomFood: () => _pendingCreateCustom = true,
        onQuickLog: (item) async {
          await _showQuickLogSheet(item);
        },
      ),
    );

    if (result != null) {
      _showQuickLogSheet(result);
    } else if (_pendingCreateCustom) {
      _pendingCreateCustom = false;
      _openCreateCustom();
    }
  }

  Future<void> _onLogRecipe() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const RecipeListScreen(pickerMode: true),
      ),
    );
  }

  Future<void> _showQuickLogSheet(FoodSearchItem item) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickFoodLogSheet(food: item),
    );
  }

  Future<void> _openCreateCustom() async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => const ManualFoodForm(),
      ),
    );
    if (food != null && mounted) {
      final item = FoodSearchItem.fromFood(food);
      _showQuickLogSheet(item);
    }
  }

  Future<void> _editEntry(FoodEntry entry) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditEntrySheet(entry: entry),
    );
  }

  Future<void> _deleteEntry(FoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('Delete "${entry.name}"?'),
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
        await ref.read(foodLogProvider).deleteEntry(entry.id);
        ref.read(dataTriggerProvider.notifier).state++;
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
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

  Map<String, List<FoodEntry>> _groupByMealType(List<FoodEntry> entries) {
    final map = <String, List<FoodEntry>>{};
    for (final entry in entries) {
      map.putIfAbsent(entry.mealType.isNotEmpty ? entry.mealType : 'other', () => []).add(entry);
    }
    return map;
  }

  String? _timeFromLoggedAt(String loggedAt) {
    if (loggedAt.length >= 16) return loggedAt.substring(11, 16);
    return null;
  }

  Widget _mealTypeBadge(String mealType) {
    final colors = {
      'breakfast': Colors.orange,
      'lunch': Colors.blue,
      'dinner': Colors.purple,
      'snack': Colors.teal,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (colors[mealType] ?? Colors.grey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mealType[0].toUpperCase() + mealType.substring(1),
        style: TextStyle(
          fontSize: 11,
          color: colors[mealType] ?? Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _shareCsv() async {
    final db = ref.read(databaseProvider);
    final entries = await db.select(db.foodEntries).get();
    if (!mounted) return;
    final csv = exportFoodEntriesToCsv(entries);
    await shareCsv(csv, 'food_entries.csv');
  }

  Future<void> _saveCsv() async {
    final db = ref.read(databaseProvider);
    final entries = await db.select(db.foodEntries).get();
    if (!mounted) return;
    final csv = exportFoodEntriesToCsv(entries);
    final path = await saveCsvToDownloads(csv, 'food_entries.csv');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(dateFoodProvider(_currentDate));
    final targetsAsync = ref.watch(macroTargetsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: DayNavigator(
          currentDate: _currentDate,
          onDateChanged: _goToDate,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Log recipe',
            onPressed: _onLogRecipe,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'share_food') {
                await _shareCsv();
              } else if (value == 'save_food') {
                await _saveCsv();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'share_food',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'save_food',
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
      body: targetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load targets')),
        data: (targets) => entriesAsync.when(
          data: (entries) {
            final consumedCals = entries.fold(0.0, (s, e) => s + e.calories);
            final consumedProtein = entries.fold(0.0, (s, e) => s + e.proteinGrams);
            final consumedCarbs = entries.fold(0.0, (s, e) => s + e.carbsGrams);
            final consumedFat = entries.fold(0.0, (s, e) => s + e.fatGrams);

            final macroBars = MacroBars(
              targets: targets,
              consumedCalories: consumedCals,
              consumedProtein: consumedProtein,
              consumedCarbs: consumedCarbs,
              consumedFat: consumedFat,
            );

            if (entries.isEmpty) {
              return ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                children: [
                  macroBars,
                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant, size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No entries for this date',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final groups = _groupByMealType(entries);
            final mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
            final sortedMeals = groups.keys.toList()
              ..sort((a, b) {
                final ai = mealOrder.indexOf(a);
                final bi = mealOrder.indexOf(b);
                if (ai == -1 && bi == -1) return a.compareTo(b);
                if (ai == -1) return 1;
                if (bi == -1) return -1;
                return ai.compareTo(bi);
              });

            return ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              children: [
                macroBars,
                for (final mealType in sortedMeals) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                    child: Row(
                      children: [
                        Text(
                          mealType[0].toUpperCase() + mealType.substring(1),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${groups[mealType]!.length}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  for (final entry in groups[mealType]!) ...[
                    Dismissible(
                      key: ValueKey('entry_${entry.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(Icons.delete,
                            color: Theme.of(context).colorScheme.onError),
                      ),
                      confirmDismiss: (_) async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete entry?'),
                            content: Text('Delete "${entry.name}"?'),
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
                          await _deleteEntry(entry);
                        }
                        return confirmed ?? false;
                      },
                      child: ListTile(
                        title: Text(entry.name),
                        subtitle: Text(
                          '${entry.calories.toInt()} cal  •  '
                          'P${entry.proteinGrams.toStringAsFixed(0)}g  '
                          'C${entry.carbsGrams.toStringAsFixed(0)}g  '
                          'F${entry.fatGrams.toStringAsFixed(0)}g'
                          '${_timeFromLoggedAt(entry.loggedAt) != null ? "  •  ${_timeFromLoggedAt(entry.loggedAt)}" : ""}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _mealTypeBadge(entry.mealType),
                          ],
                        ),
                        onTap: () => _editEntry(entry),
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Failed to load entries'),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onSearch,
        tooltip: 'Log new food',
        child: const Icon(Icons.add),
      ),
    );
  }
}
