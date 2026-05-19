import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/open_food_facts_client.dart';
import '../../../core/api/models/food_result.dart';
import '../../../core/database/database.dart';
import '../../../providers/food_search_provider.dart';
import '../../../providers/local_food_list_provider.dart';
import 'barcode_scanner.dart';

class FoodSearchDelegate extends SearchDelegate<FoodSearchItem?> {
  final FoodSearchService searchService;
  final OpenFoodFactsClient apiClient;
  final Future<Food?> Function(BuildContext, {Food? existingFood}) onCreateCustomFood;
  final Future<void> Function(FoodSearchItem)? onQuickLog;
  final void Function(Food)? onEditFood;
  final Future<void> Function(Food)? onDeleteFood;
  String _searchMode = 'local';

  FoodSearchDelegate({
    required this.searchService,
    required this.apiClient,
    required this.onCreateCustomFood,
    this.onQuickLog,
    this.onEditFood,
    this.onDeleteFood,
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
            // ignore: use_build_context_synchronously
            final food = await onCreateCustomFood(navigator.context);
            if (food != null && navigator.mounted) {
              navigator.pop<FoodSearchItem?>(FoodSearchItem.fromFood(food));
            }
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
        onSelectWebItem: (item) async {
          final nav = Navigator.of(context);
          final syntheticFood = Food(
            id: -1,
            name: item.name,
            servingLabel: item.servingLabel,
            servingQuantity: item.servingQuantity,
            servingUnit: item.servingUnit,
            caloriesPerServing: item.caloriesPerServing,
            proteinPerServing: item.proteinPerServing,
            carbsPerServing: item.carbsPerServing,
            fatPerServing: item.fatPerServing,
            barcode: item.barcode,
            brand: item.brand,
            source: item.source,
            createdAt: '',
          );
          final food = await onCreateCustomFood(context, existingFood: syntheticFood);
          if (food != null) {
            _searchMode = 'local';
            query = '';
            nav.pop<FoodSearchItem?>(FoodSearchItem.fromFood(food));
          }
        },
        onEditFood: onEditFood,
        onDeleteFood: onDeleteFood,
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
        onSelectWebItem: (item) async {
          final nav = Navigator.of(context);
          final syntheticFood = Food(
            id: -1,
            name: item.name,
            servingLabel: item.servingLabel,
            servingQuantity: item.servingQuantity,
            servingUnit: item.servingUnit,
            caloriesPerServing: item.caloriesPerServing,
            proteinPerServing: item.proteinPerServing,
            carbsPerServing: item.carbsPerServing,
            fatPerServing: item.fatPerServing,
            barcode: item.barcode,
            brand: item.brand,
            source: item.source,
            createdAt: '',
          );
          final food = await onCreateCustomFood(context, existingFood: syntheticFood);
          if (food != null) {
            _searchMode = 'local';
            query = '';
            nav.pop<FoodSearchItem?>(FoodSearchItem.fromFood(food));
          }
        },
        onEditFood: onEditFood,
        onDeleteFood: onDeleteFood,
      );
}

class _FoodSearchContent extends ConsumerStatefulWidget {
  final String query;
  final FoodSearchService searchService;
  final String searchMode;
  final ValueChanged<String> onSearchModeChanged;
  final Future<Food?> Function(BuildContext, {Food? existingFood}) onCreateCustomFood;
  final Future<void> Function(FoodSearchItem)? onQuickLog;
  final void Function(FoodSearchItem item) onSelectItem;
  final Future<void> Function(FoodSearchItem item) onSelectWebItem;
  final void Function(Food)? onEditFood;
  final Future<void> Function(Food)? onDeleteFood;

  const _FoodSearchContent({
    required this.query,
    required this.searchService,
    required this.searchMode,
    required this.onSearchModeChanged,
    required this.onCreateCustomFood,
    this.onQuickLog,
    required this.onSelectItem,
    required this.onSelectWebItem,
    this.onEditFood,
    this.onDeleteFood,
  });

  @override
  ConsumerState<_FoodSearchContent> createState() => _FoodSearchContentState();
}

class _FoodSearchContentState extends ConsumerState<_FoodSearchContent> {
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
                  onCreateCustomFood: widget.onCreateCustomFood,
                  onQuickLog: widget.onQuickLog,
                  onSelectItem: widget.onSelectItem,
                  onEditFood: widget.onEditFood,
                  onDeleteFood: widget.onDeleteFood,
                )
               : _WebSearchContent(
                    query: widget.query,
                    searchService: widget.searchService,
                    onSelectItem: widget.onSelectItem,
                    onSelectWebItem: widget.onSelectWebItem,
                    immediateQuery: _localSearchMode == 'web' && widget.query.isNotEmpty
                        ? widget.query
                        : null,
                  ),
        ),
      ],
    );
  }
}

class _LocalSearchContent extends ConsumerWidget {
  final String query;
  final Future<Food?> Function(BuildContext, {Food? existingFood}) onCreateCustomFood;
  final Future<void> Function(FoodSearchItem)? onQuickLog;
  final void Function(FoodSearchItem item) onSelectItem;
  final void Function(Food)? onEditFood;
  final Future<void> Function(Food)? onDeleteFood;

  const _LocalSearchContent({
    required this.query,
    required this.onCreateCustomFood,
    this.onQuickLog,
    required this.onSelectItem,
    this.onEditFood,
    this.onDeleteFood,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(localFoodListProvider(query));

    return itemsAsync.when(
      data: (items) => _buildList(context, items),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Error loading foods')),
    );
  }

  Widget _buildList(BuildContext context, List<FoodSearchItem> items) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Create custom food'),
          onTap: () async {
            final nav = Navigator.of(context);
            final food = await onCreateCustomFood(context);
            if (food != null && nav.mounted) {
              nav.pop<FoodSearchItem?>(
                FoodSearchItem.fromFood(food),
              );
            }
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
                '• ${item.fatPerServing.toStringAsFixed(1)}g F  '
                '• ${item.carbsPerServing.toStringAsFixed(1)}g C  '
                '• ${item.proteinPerServing.toStringAsFixed(1)}g P';
            final brandLine = item.brand != null && item.brand!.isNotEmpty
                ? '${item.brand} • ${item.servingLabel}'
                : item.servingLabel;
            return ListTile(
              title: Text(item.name),
              subtitle: Text(
                '$macroText\n$brandLine',
              ),
              isThreeLine: true,
              onTap: () => onQuickLog != null
                  ? onQuickLog!(item)
                  : onSelectItem(item),
              onLongPress: () async {
                if (onDeleteFood != null && item.localId != null) {
                  final food = Food(
                    id: item.localId!,
                    name: item.name,
                    servingLabel: item.servingLabel,
                    servingQuantity: item.servingQuantity,
                    servingUnit: item.servingUnit,
                    caloriesPerServing: item.caloriesPerServing,
                    proteinPerServing: item.proteinPerServing,
                    carbsPerServing: item.carbsPerServing,
                    fatPerServing: item.fatPerServing,
                    barcode: item.barcode,
                    brand: item.brand,
                    source: item.source,
                    createdAt: '',
                  );
                  await onDeleteFood!(food);
                }
              },
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () {
                  if (onEditFood != null && item.localId != null) {
                    final food = Food(
                      id: item.localId!,
                      name: item.name,
                      servingLabel: item.servingLabel,
                      servingQuantity: item.servingQuantity,
                      servingUnit: item.servingUnit,
                      caloriesPerServing: item.caloriesPerServing,
                      proteinPerServing: item.proteinPerServing,
                      carbsPerServing: item.carbsPerServing,
                      fatPerServing: item.fatPerServing,
                      barcode: item.barcode,
                      brand: item.brand,
                      source: item.source,
                      createdAt: '',
                    );
                    onEditFood!(food);
                  }
                },
                tooltip: 'Edit food',
              ),
            );
          }),
      ],
    );
  }
}

class _WebSearchContent extends StatefulWidget {
  final String query;
  final FoodSearchService searchService;
  final void Function(FoodSearchItem item) onSelectItem;
  final Future<void> Function(FoodSearchItem item) onSelectWebItem;
  final String? immediateQuery;

  const _WebSearchContent({
    required this.query,
    required this.searchService,
    required this.onSelectItem,
    required this.onSelectWebItem,
    this.immediateQuery,
  });

  @override
  State<_WebSearchContent> createState() => _WebSearchContentState();
}

class _WebSearchContentState extends State<_WebSearchContent> {
  Timer? _debounceTimer;
  String _debouncedQuery = '';
  int _retryTrigger = 0;
  bool _hasUserEdited = false;

  @override
  void initState() {
    super.initState();
    if (widget.immediateQuery != null && widget.immediateQuery!.isNotEmpty) {
      _debouncedQuery = widget.immediateQuery!;
      _hasUserEdited = true;
    }
  }

  @override
  void didUpdateWidget(_WebSearchContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _retryTrigger = 0;
      _hasUserEdited = true;
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
    if (!_hasUserEdited) return;
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
          return GestureDetector(
            onTap: () => setState(() => _retryTrigger++),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No results found. Tap to retry.'),
            ),
          );
        }

        return ListView(
          children: items.map((item) {
            final macroText =
                '${item.caloriesPerServing.toStringAsFixed(0)} cal  '
                '• ${item.fatPerServing.toStringAsFixed(1)}g F  '
                '• ${item.carbsPerServing.toStringAsFixed(1)}g C  '
                '• ${item.proteinPerServing.toStringAsFixed(1)}g P';
            final brandLine = item.brand != null && item.brand!.isNotEmpty
                ? '${item.brand} • ${item.servingLabel}'
                : item.servingLabel;
            return ListTile(
              title: Text(item.name),
              subtitle: Text(
                '$macroText\n$brandLine',
              ),
              isThreeLine: true,
              onTap: () => widget.onSelectWebItem(item),
            );
          }).toList(),
        );
      },
    );
  }
}
