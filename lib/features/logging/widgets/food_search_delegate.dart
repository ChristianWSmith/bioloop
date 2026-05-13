import 'package:flutter/material.dart';
import '../../../providers/food_search_provider.dart';

class FoodSearchDelegate extends SearchDelegate<FoodSearchItem?> {
  final FoodSearchService searchService;
  final VoidCallback onCreateCustomFood;

  FoodSearchDelegate({
    required this.searchService,
    required this.onCreateCustomFood,
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
          FutureBuilder<List<FoodSearchItem>>(
            key: ValueKey(query),
            future: searchService.search(query),
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
                    onTap: () => close(context, item),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}
