import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/food_search_provider.dart';
import '../../../providers/recent_foods_provider.dart';

class FoodSearchDelegate extends SearchDelegate<FoodSearchItem?> {
  final FoodSearchService searchService;
  final VoidCallback onCreateCustomFood;
  final ValueChanged<FoodSearchItem>? onQuickLog;

  FoodSearchDelegate({
    required this.searchService,
    required this.onCreateCustomFood,
    this.onQuickLog,
  });

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context);
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildContent(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildContent(context);

  Widget _buildContent(BuildContext context) {
    return ListView(
      children: [
        if (query.isEmpty)
          _RecentFoodsSection(
            onSelectItem: (item) => close(context, item),
            onQuickLog: onQuickLog != null
                ? (item) {
                    onQuickLog!(item);
                    close(context, null);
                  }
                : null,
          ),
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Create custom food'),
          onTap: () {
            onCreateCustomFood();
            close(context, null);
          },
        ),
        if (query.isNotEmpty) ...[
          const Divider(),
          _DebouncedSearch(
            query: query,
            searchService: searchService,
            onSelectItem: (item) => close(context, item),
          ),
        ],
      ],
    );
  }
}

class _RecentFoodsSection extends ConsumerWidget {
  final void Function(FoodSearchItem item) onSelectItem;
  final ValueChanged<FoodSearchItem>? onQuickLog;

  const _RecentFoodsSection({required this.onSelectItem, this.onQuickLog});

  String _formatLastUsed(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentFoods = ref.watch(recentFoodsProvider);
    return recentFoods.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Recent Foods',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            ...items.map((item) {
              final macroText =
                  '${item.food.caloriesPerServing.toStringAsFixed(0)} cal  '
                  '• ${item.food.proteinPerServing.toStringAsFixed(1)}g P  '
                  '• ${item.food.carbsPerServing.toStringAsFixed(1)}g C  '
                  '• ${item.food.fatPerServing.toStringAsFixed(1)}g F';
              return ListTile(
                title: Text(item.food.name),
                subtitle: Text(
                  '$macroText\n${item.food.servingLabel}  •  ${_formatLastUsed(item.lastUsed)}',
                ),
                isThreeLine: true,
                onTap: () => onSelectItem(item.food),
                trailing: onQuickLog != null
                    ? IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Quick log',
                        onPressed: () => onQuickLog!(item.food),
                      )
                    : null,
              );
            }),
            const Divider(),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not load recent foods'),
      ),
    );
  }
}

class _DebouncedSearch extends StatefulWidget {
  final String query;
  final FoodSearchService searchService;
  final void Function(FoodSearchItem item) onSelectItem;

  const _DebouncedSearch({
    required this.query,
    required this.searchService,
    required this.onSelectItem,
  });

  @override
  State<_DebouncedSearch> createState() => _DebouncedSearchState();
}

class _DebouncedSearchState extends State<_DebouncedSearch> {
  Timer? _debounceTimer;
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    _startDebounce();
  }

  @override
  void didUpdateWidget(_DebouncedSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _startDebounce();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _startDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _debouncedQuery = widget.query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_debouncedQuery.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<FoodSearchItem>>(
      key: ValueKey(_debouncedQuery),
      future: widget.searchService.search(_debouncedQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No results found'),
          );
        }

        return Column(
          children: items.map((item) {
            final macroText =
                '${item.caloriesPerServing.toStringAsFixed(0)} cal  '
                '• ${item.proteinPerServing.toStringAsFixed(1)}g P  '
                '• ${item.carbsPerServing.toStringAsFixed(1)}g C  '
                '• ${item.fatPerServing.toStringAsFixed(1)}g F';
            return ListTile(
              title: Text(item.name),
              subtitle: Text(
                '$macroText\n${item.servingLabel}',
              ),
              isThreeLine: true,
              onTap: () => widget.onSelectItem(item),
            );
          }).toList(),
        );
      },
    );
  }
}
