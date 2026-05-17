import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/core/api/open_food_facts_client.dart';
import 'package:bioloop/providers/data_trigger_provider.dart';
import 'package:bioloop/providers/database_provider.dart';
import 'package:bioloop/providers/food_search_provider.dart';
import 'package:bioloop/features/logging/widgets/food_search_delegate.dart';

void main() {
  group('FoodSearchDelegate toggle', () {
    testWidgets('segmented toggle responds and survives Enter key',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Chicken Breast',
        servingLabel: '100g',
        caloriesPerServing: 165,
        proteinPerServing: 31,
        carbsPerServing: 0,
        fatPerServing: 3.6,
        createdAt: now,
      ));
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Brown Rice',
        servingLabel: '100g',
        caloriesPerServing: 111,
        proteinPerServing: 2.6,
        carbsPerServing: 23,
        fatPerServing: 0.9,
        createdAt: now,
      ));
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Chicken Breast',
        calories: 165,
        proteinGrams: 31,
        carbsGrams: 0,
        fatGrams: 3.6,
        servings: 1,
        servingLabel: '100g',
        mealType: 'lunch',
        foodId: Value(1),
        loggedAt: '2026-05-15T12:00:00',
      ));
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Brown Rice',
        calories: 111,
        proteinGrams: 2.6,
        carbsGrams: 23,
        fatGrams: 0.9,
        servings: 1,
        servingLabel: '100g',
        mealType: 'dinner',
        foodId: Value(2),
        loggedAt: '2026-05-15T13:00:00',
      ));

      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final service = FoodSearchService(db: db, apiClient: mockApiClient);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            openFoodFactsClientProvider.overrideWithValue(mockApiClient),
            foodSearchServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showSearch<FoodSearchItem?>(
                    context: context,
                    delegate: FoodSearchDelegate(
                      searchService: service,
                      apiClient: mockApiClient,
                      onCreateCustomFood: () {},
                    ),
                  );
                },
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      // Initial state: My Foods selected, local content visible
      expect(find.text('My Foods'), findsOneWidget);
      expect(find.text('Create custom food'), findsOneWidget);

      // Tap "Search the Web" — content should switch
      await tester.tap(find.text('Search the Web'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a search term'), findsOneWidget);
      expect(find.text('Create custom food'), findsNothing);

      // Tap back to "My Foods" — content should switch back
      await tester.tap(find.text('My Foods'));
      await tester.pumpAndSettle();

      expect(find.text('Create custom food'), findsOneWidget);
      expect(find.text('Enter a search term'), findsNothing);

      // Type a query and press Enter (triggers buildResults)
      await tester.enterText(find.byType(TextField), 'chicken');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Toggle still on My Foods after Enter
      expect(find.text('Create custom food'), findsOneWidget);

      // Toggle to Search the Web — should still work after Enter
      await tester.tap(find.text('Search the Web'));
      await tester.pump(); // rebuild with web content, start 400ms debounce
      await tester.pump(const Duration(milliseconds: 500)); // fire debounce → _debouncedQuery set
      await tester.pump(); // FutureBuilder starts async searchWeb
      await tester.pump(); // async completes, FutureBuilder gets empty results
      // Web search with query 'chicken' uses debounce + mock API → "No results found"
      expect(find.text('No results found'), findsOneWidget);
    });
  });

  group('FoodSearchDelegate deletion refresh', () {
    testWidgets('deleted food disappears from list immediately', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Oatmeal',
        servingLabel: '1 cup',
        caloriesPerServing: 150,
        proteinPerServing: 5,
        carbsPerServing: 27,
        fatPerServing: 3,
        createdAt: now,
      ));
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Oatmeal',
        calories: 150,
        proteinGrams: 5,
        carbsGrams: 27,
        fatGrams: 3,
        servings: 1,
        servingLabel: '1 cup',
        mealType: 'breakfast',
        foodId: Value(1),
        loggedAt: '2026-05-16T08:00:00',
      ));

      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final service = FoodSearchService(db: db, apiClient: mockApiClient);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            openFoodFactsClientProvider.overrideWithValue(mockApiClient),
            foodSearchServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showSearch<FoodSearchItem?>(
                    context: context,
                    delegate: FoodSearchDelegate(
                      searchService: service,
                      apiClient: mockApiClient,
                      onCreateCustomFood: () {},
                      onDeleteFood: (food) async {
                        await db.deleteFood(food.id);
                        ProviderScope.containerOf(context)
                            .read(dataTriggerProvider.notifier)
                            .state++;
                      },
                    ),
                  );
                },
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      // Food should be visible
      expect(find.text('Oatmeal'), findsOneWidget);

      // Long-press to delete
      await tester.longPress(find.text('Oatmeal'));
      await tester.pumpAndSettle();

      // Food should disappear from the list
      expect(find.text('Oatmeal'), findsNothing);
    });
  });
}
