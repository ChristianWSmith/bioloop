import 'dart:async';
import 'package:flutter/material.dart';
import '../../../providers/food_search_provider.dart';

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
  Widget buildResults(BuildContext context) => _FoodSearchContent(
        query: query,
        searchService: searchService,
        onCreateCustomFood: onCreateCustomFood,
        onQuickLog: onQuickLog,
        onSelectItem: (item) => close(context, item),
      );

  @override
  Widget buildSuggestions(BuildContext context) => _FoodSearchContent(
        query: query,
        searchService: searchService,
        onCreateCustomFood: onCreateCustomFood,
        onQuickLog: onQuickLog,
        onSelectItem: (item) => close(context, item),
      );
}

class _FoodSearchContent extends StatefulWidget {
  final String query;
  final FoodSearchService searchService;
  final VoidCallback onCreateCustomFood;
  final ValueChanged<FoodSearchItem>? onQuickLog;
  final void Function(FoodSearchItem item) onSelectItem;

  const _FoodSearchContent({
    required this.query,
    required this.searchService,
    required this.onCreateCustomFood,
    this.onQuickLog,
    required this.onSelectItem,
  });

  @override
  State<_FoodSearchContent> createState() => _FoodSearchContentState();
}

class _FoodSearchContentState extends State<_FoodSearchContent> {
  String _searchMode = 'local';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'local', label: Text('My Foods')),
              ButtonSegment(value: 'web', label: Text('Search the Web')),
            ],
            selected: {_searchMode},
            onSelectionChanged: (v) => setState(() => _searchMode = v.first),
          ),
        ),
        Expanded(
          child: _searchMode == 'local'
              ? _LocalSearchContent(
                  query: widget.query,
                  searchService: widget.searchService,
                  onCreateCustomFood: widget.onCreateCustomFood,
                  onQuickLog: widget.onQuickLog,
                  onSelectItem: widget.onSelectItem,
                )
              : _WebSearchContent(
                  query: widget.query,
                  searchService: widget.searchService,
                  onSelectItem: widget.onSelectItem,
                ),
        ),
      ],
    );
  }
}

class _LocalSearchContent extends StatelessWidget {
  final String query;
  final FoodSearchService searchService;
  final VoidCallback onCreateCustomFood;
  final ValueChanged<FoodSearchItem>? onQuickLog;
  final void Function(FoodSearchItem item) onSelectItem;

  const _LocalSearchContent({
    required this.query,
    required this.searchService,
    required this.onCreateCustomFood,
    this.onQuickLog,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FoodSearchItem>>(
      future: searchService.searchLocal(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        return ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Create custom food'),
              onTap: () {
                onCreateCustomFood();
              },
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No foods found')),
              )
            else
              ...items.map((item) {
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
                  onTap: () => onSelectItem(item),
                  trailing: onQuickLog != null
                      ? IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Quick log',
                          onPressed: () => onQuickLog!(item),
                        )
                      : null,
                );
              }),
          ],
        );
      },
    );
  }
}

class _WebSearchContent extends StatefulWidget {
  final String query;
  final FoodSearchService searchService;
  final void Function(FoodSearchItem item) onSelectItem;

  const _WebSearchContent({
    required this.query,
    required this.searchService,
    required this.onSelectItem,
  });

  @override
  State<_WebSearchContent> createState() => _WebSearchContentState();
}

class _WebSearchContentState extends State<_WebSearchContent> {
  Timer? _debounceTimer;
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    _startDebounce();
  }

  @override
  void didUpdateWidget(_WebSearchContent oldWidget) {
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
    if (widget.query.isEmpty) {
      return const Center(child: Text('Enter a search term'));
    }

    if (_debouncedQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<FoodSearchItem>>(
      key: ValueKey(_debouncedQuery),
      future: widget.searchService.searchWeb(_debouncedQuery),
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

        return ListView(
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
