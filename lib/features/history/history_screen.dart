import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/food_log_provider.dart';
import 'export.dart';
import 'widgets/edit_entry_sheet.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDateHeader(String dateStr) {
  final parts = dateStr.split('-');
  if (parts.length != 3) return dateStr;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return dateStr;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(year, month, day);
  final diff = today.difference(date).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';

  return '${_monthNames[month - 1]} $day, $year';
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final List<FoodEntry> _entries = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _allLoaded = false;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _allLoaded) return;
    setState(() => _loadingMore = true);

    try {
      final newEntries = await ref.read(foodLogProvider).getEntriesPaginated(
            offset: _entries.length,
            limit: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        if (newEntries.length < _pageSize) _allLoaded = true;
        _entries.addAll(newEntries);
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _entries.clear();
      _allLoaded = false;
      _loading = true;
    });
    await _loadMore();
  }

  Map<String, List<FoodEntry>> _groupByDate() {
    final map = <String, List<FoodEntry>>{};
    for (final entry in _entries) {
      final date = entry.loggedAt.substring(0, 10);
      map.putIfAbsent(date, () => []).add(entry);
    }
    return map;
  }

  Future<void> _editEntry(FoodEntry entry) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditEntrySheet(entry: entry),
    );

    if (result == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'History',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    final db = ref.read(databaseProvider);
                    final entries =
                        await db.select(db.foodEntries).get();
                    if (!context.mounted) return;
                    final csv = exportFoodEntriesToCsv(entries);
                    if (value == 'share_food') {
                      await shareCsv(csv, 'food_entries.csv');
                    } else if (value == 'save_food') {
                      final path = await saveCsvToDownloads(
                        csv,
                        'food_entries.csv',
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saved to $path')),
                      );
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
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const Center(child: Text('No food logged yet'))
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final groups = _groupByDate();
    final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final items = <_ListItem>[];
    for (final date in dates) {
      items.add(_ListItem.header(date));
      for (final entry in groups[date]!) {
        items.add(_ListItem.entry(entry));
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (ctx, index) {
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = items[index];
          if (item.isHeader) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                _formatDateHeader(item.date!),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            );
          }

          final entry = item.entry!;
          final loggedAt = entry.loggedAt;
          final timeStr =
              loggedAt.length >= 16 ? loggedAt.substring(11, 16) : '';

          return Dismissible(
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
                try {
                  await ref.read(foodLogProvider).deleteEntry(entry.id);
                  if (mounted) {
                    setState(
                        () => _entries.removeWhere((e) => e.id == entry.id));
                  }
                  return true;
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
                  return false;
                }
              }
              return false;
            },
            child: ListTile(
              title: Text(entry.name),
              subtitle: Text(
                '${entry.calories.toInt()} cal  •  P${entry.proteinGrams.toStringAsFixed(0)}g  C${entry.carbsGrams.toStringAsFixed(0)}g  F${entry.fatGrams.toStringAsFixed(0)}g  •  $timeStr',
              ),
              trailing: _mealTypeBadge(entry.mealType),
              onTap: () => _editEntry(entry),
            ),
          );
        },
      ),
    );
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
}

class _ListItem {
  final String? date;
  final FoodEntry? entry;

  _ListItem._({this.date, this.entry});

  factory _ListItem.header(String date) => _ListItem._(date: date);
  factory _ListItem.entry(FoodEntry entry) => _ListItem._(entry: entry);

  bool get isHeader => date != null;
}
