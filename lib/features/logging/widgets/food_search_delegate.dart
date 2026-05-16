import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/open_food_facts_client.dart';
import '../../../core/api/models/food_result.dart';
import '../../../providers/food_search_provider.dart';
import 'barcode_scanner.dart';

class FoodSearchDelegate extends SearchDelegate<FoodSearchItem?> {
  final FoodSearchService searchService;
  final OpenFoodFactsClient apiClient;
  final VoidCallback onCreateCustomFood;
  final Future<void> Function(FoodSearchItem)? onQuickLog;
  String _searchMode = 'local';

  FoodSearchDelegate({
    required this.searchService,
    required this.apiClient,
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
      IconButton(
        icon: const Icon(Icons.qr_code_scanner),
        tooltip: 'Scan barcode',
        onPressed: () async {
          final navigator = Navigator.of(context);
          final result = await navigator.push<Object?>(
            MaterialPageRoute(
              builder: (_) => BarcodeScannerScreen(apiClient: apiClient),
            ),
          );
          if (result is FoodResult) {
            final item = FoodSearchItem.fromFoodResult(result);
            await onQuickLog?.call(item);
            navigator.pop<FoodSearchItem?>(null);
          } else if (result == 'manual') {
            onCreateCustomFood();
            navigator.pop<FoodSearchItem?>(null);
          }
        },
      ),
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
        searchMode: _searchMode,
        onSearchModeChanged: (v) => _searchMode = v,
        onCreateCustomFood: onCreateCustomFood,
        onQuickLog: onQuickLog != null
            ? (item) async {
                final nav = Navigator.of(context);
                await onQuickLog!(item);
                nav.pop<FoodSearchItem?>(null);
              }
            : null,
        onSelectItem: (item) => close(context, item),
      );

  @override
  Widget buildSuggestions(BuildContext context) => _FoodSearchContent(
        query: query,
        searchService: searchService,
        searchMode: _searchMode,
        onSearchModeChanged: (v) => _searchMode = v,
        onCreateCustomFood: onCreateCustomFood,
        onQuickLog: onQuickLog != null
            ? (item) async {
                final nav = Navigator.of(context);
                await onQuickLog!(item);
                nav.pop<FoodSearchItem?>(null);
              }
            : null,
        onSelectItem: (item) => close(context, item),
      );
}

class _FoodSearchContent extends StatefulWidget {
  final String query;
  final FoodSearchService searchService;
  final String searchMode;
  final ValueChanged<String> onSearchModeChanged;
  final VoidCallback onCreateCustomFood;
  final Future<void> Function(FoodSearchItem)? onQuickLog;
  final void Function(FoodSearchItem item) onSelectItem;

  const _FoodSearchContent({
    required this.query,
    required this.searchService,
    required this.searchMode,
    required this.onSearchModeChanged,
    required this.onCreateCustomFood,
    this.onQuickLog,
    required this.onSelectItem,
  });

  @override
  State<_FoodSearchContent> createState() => _FoodSearchContentState();
}

class _FoodSearchContentState extends State<_FoodSearchContent> {
  late String _localSearchMode;

  @override
  void initState() {
    super.initState();
    _localSearchMode = widget.searchMode;
  }

  @override
  void didUpdateWidget(_FoodSearchContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchMode != oldWidget.searchMode) {
      _localSearchMode = widget.searchMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'local', label: Text('My Foods')),
                ButtonSegment(value: 'web', label: Text('Search the Web')),
              ],
              selected: {_localSearchMode},
              onSelectionChanged: (v) {
                setState(() => _localSearchMode = v.first);
                widget.onSearchModeChanged(v.first);
              },
            ),
          ),
        ),
        Expanded(
          child: _localSearchMode == 'local'
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
  final Future<void> Function(FoodSearchItem)? onQuickLog;
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
                Navigator.of(context).pop<FoodSearchItem?>(null);
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
                  onTap: () => onQuickLog != null
                      ? onQuickLog!(item)
                      : onSelectItem(item),
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
  int _retryTrigger = 0;

  @override
  void initState() {
    super.initState();
    _startDebounce();
  }

  @override
  void didUpdateWidget(_WebSearchContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _retryTrigger = 0;
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

    return FutureBuilder<WebSearchResult>(
      key: ValueKey('$_debouncedQuery-$_retryTrigger'),
      future: widget.searchService.searchWeb(_debouncedQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final result = snapshot.data;
        if (result is WebSearchFailure) {
          return GestureDetector(
            onTap: () => setState(() => _retryTrigger++),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Search failed. Tap to retry.'),
            ),
          );
        }

        final items = (result as WebSearchSuccess?)?.items ?? [];
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
