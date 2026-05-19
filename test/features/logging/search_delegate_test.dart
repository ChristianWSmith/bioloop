import 'dart:convert';
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
import 'package:bioloop/features/logging/widgets/manual_food_form.dart';

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
        client: MockClient((_) async => http.Response(
          jsonEncode({'products': [
            {
              'product_name': 'Test Product',
              'serving_size': '100g',
              'nutriments': {
                'energy-kcal_serving': 100,
                'proteins_serving': 10,
                'carbohydrates_serving': 10,
                'fat_serving': 5,
              },
              'code': '123',
            }
          ]}),
          200,
        )),
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
                      onCreateCustomFood: (context, {existingFood}) async => null,
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

      // Toggle to Search the Web — should trigger immediate search
      await tester.tap(find.text('Search the Web'));
      await tester.pump(); // rebuild with web content, immediateQuery triggers search
      await tester.pump(); // FutureBuilder starts
      await tester.pump(); // Future completes (mock returns results immediately)
      // Web search with query 'chicken' uses immediateQuery → shows results
      expect(find.text('Test Product'), findsOneWidget);
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
                      onCreateCustomFood: (context, {existingFood}) async => null,
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

  group('Web search retry', () {
    testWidgets('tap retry on empty results re-triggers search', (tester) async {
      int callCount = 0;
      OpenFoodFactsClient buildClient() {
        return OpenFoodFactsClient(
          client: MockClient((request) async {
            callCount++;
            if (callCount <= 3) {
              return http.Response(jsonEncode({'products': []}), 200);
            }
            return http.Response(
              jsonEncode({
                'products': [
                  {
                    'product_name': 'Chicken Breast',
                    'serving_size': '100g',
                    'nutriments': {
                      'energy-kcal_serving': 165,
                      'proteins_serving': 31,
                      'carbohydrates_serving': 0,
                      'fat_serving': 3.6,
                    },
                    'code': '123',
                  }
                ]
              }),
              200,
            );
          }),
        );
      }

      final mockApiClient = buildClient();
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

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
                      onCreateCustomFood: (context, {existingFood}) async => null,
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
      await tester.pump();
      await tester.pumpAndSettle();

      // Switch to web search (query is empty, so no immediate search)
      await tester.tap(find.text('Search the Web'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Enter a search term'), findsOneWidget);

      // Type query and press Enter
      await tester.enterText(find.byType(TextField), 'chicken');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      // Wait for debounce (400ms)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      // Client retries empty results: 1s + 2s backoff
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('No results found. Tap to retry.'), findsOneWidget);

      // Tap retry — triggers new search (callCount is now 3, next call returns results)
      await tester.tap(find.text('No results found. Tap to retry.'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      // Results should appear after retry
      expect(find.text('Chicken Breast'), findsOneWidget);
    });
  });

  group('Custom food creation navigation', () {
    testWidgets('back out of form returns to search delegate', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response('{"products": []}', 200)),
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
                      onCreateCustomFood: (context, {existingFood}) async {
                        return await Navigator.of(context).push<Food>(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(),
                              body: const Text('Manual Food Form'),
                            ),
                          ),
                        );
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

      expect(find.text('Create custom food'), findsOneWidget);

      await tester.tap(find.text('Create custom food'));
      await tester.pumpAndSettle();

      expect(find.text('Manual Food Form'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Create custom food'), findsOneWidget);
      expect(find.text('Manual Food Form'), findsNothing);
    });

    testWidgets('save food returns it for quick-logging', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response('{"products": []}', 200)),
      );
      final service = FoodSearchService(db: db, apiClient: mockApiClient);
      FoodSearchItem? returnedItem;

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
                onPressed: () async {
                  returnedItem = await showSearch<FoodSearchItem?>(
                    context: context,
                    delegate: FoodSearchDelegate(
                      searchService: service,
                      apiClient: mockApiClient,
                      onCreateCustomFood: (buildContext, {existingFood}) async {
                        return await Navigator.of(buildContext).push<Food>(
                          MaterialPageRoute(
                            builder: (formContext) => Scaffold(
                              body: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(formContext).pop(
                                    Food(
                                      id: 1,
                                      name: 'Custom Oats',
                                      servingLabel: 'cup',
                                      servingQuantity: 1,
                                      servingUnit: 'cup',
                                      caloriesPerServing: 150,
                                      proteinPerServing: 5,
                                      carbsPerServing: 27,
                                      fatPerServing: 3,
                                      barcode: null,
                                      brand: null,
                                      source: 'manual',
                                      createdAt: '',
                                    ),
                                  );
                                },
                                child: const Text('Save'),
                              ),
                            ),
                          ),
                        );
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

      await tester.tap(find.text('Create custom food'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(returnedItem, isNotNull);
      expect(returnedItem!.name, 'Custom Oats');
      expect(returnedItem!.caloriesPerServing, 150);
    });
  });

  group('Brand display', () {
    testWidgets('local food with brand shows brand in subtitle', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Brand Oats',
        servingLabel: '100g',
        caloriesPerServing: 389,
        proteinPerServing: 16.9,
        carbsPerServing: 66.3,
        fatPerServing: 6.9,
        brand: Value('Quaker'),
        createdAt: now,
      ));
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Brand Oats',
        calories: 389,
        proteinGrams: 16.9,
        carbsGrams: 66.3,
        fatGrams: 6.9,
        servings: 1,
        servingLabel: '100g',
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
                      onCreateCustomFood: (context, {existingFood}) async => null,
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

      expect(find.text('Brand Oats'), findsOneWidget);
      expect(find.textContaining('Quaker'), findsOneWidget);
    });

    testWidgets('local food without brand shows no brand text', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Plain Oats',
        servingLabel: '100g',
        caloriesPerServing: 389,
        proteinPerServing: 16.9,
        carbsPerServing: 66.3,
        fatPerServing: 6.9,
        createdAt: now,
      ));
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Plain Oats',
        calories: 389,
        proteinGrams: 16.9,
        carbsGrams: 66.3,
        fatGrams: 6.9,
        servings: 1,
        servingLabel: '100g',
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
                      onCreateCustomFood: (context, {existingFood}) async => null,
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

      expect(find.text('Plain Oats'), findsOneWidget);
      expect(find.textContaining('100g'), findsOneWidget);
    });

    testWidgets('web search result with brand shows brand in subtitle', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response(
          jsonEncode({'products': [
            {
              'product_name': 'Branded Yogurt',
              'serving_size': '150g',
              'nutriments': {
                'energy-kcal_serving': 120,
                'proteins_serving': 10,
                'carbohydrates_serving': 15,
                'fat_serving': 3,
              },
              'code': '123',
              'brands': 'Danone',
            }
          ]}),
          200,
        )),
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
                      onCreateCustomFood: (context, {existingFood}) async => null,
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

      // Switch to web search
      await tester.tap(find.text('Search the Web'));
      await tester.pumpAndSettle();

      // Type query and press Enter
      await tester.enterText(find.byType(TextField), 'yogurt');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(); // FutureBuilder starts
      await tester.pump(); // Future completes

      expect(find.text('Branded Yogurt'), findsOneWidget);
      expect(find.textContaining('Danone'), findsOneWidget);
    });
  });

  group('Web search tap opens form', () {
    testWidgets('tapping web result opens ManualFoodForm pre-filled', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response(
          jsonEncode({'products': [
            {
              'product_name': 'Test Yogurt',
              'serving_size': '150g',
              'nutriments': {
                'energy-kcal_serving': 120,
                'proteins_serving': 10,
                'carbohydrates_serving': 15,
                'fat_serving': 3,
              },
              'code': '123',
              'brands': 'Danone',
            }
          ]}),
          200,
        )),
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
                      onCreateCustomFood: (context, {existingFood}) async {
                        return await Navigator.of(context).push<Food>(
                          MaterialPageRoute(
                            builder: (_) => ProviderScope(
                              overrides: [
                                databaseProvider.overrideWithValue(db),
                              ],
                              child: ManualFoodForm(existingFood: existingFood),
                            ),
                          ),
                        );
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

      // Switch to web search
      await tester.tap(find.text('Search the Web'));
      await tester.pumpAndSettle();

      // Type query and press Enter
      await tester.enterText(find.byType(TextField), 'yogurt');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Yogurt'), findsOneWidget);

      // Tap the web result
      await tester.tap(find.text('Test Yogurt'));
      await tester.pumpAndSettle();

      // ManualFoodForm should be open with pre-filled data
      expect(find.text('Edit Food'), findsOneWidget);
      expect(find.text('Test Yogurt'), findsOneWidget);
    });

    testWidgets('save web food inserts into DB and closes delegate with result', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response(
          jsonEncode({'products': [
            {
              'product_name': 'Test Yogurt',
              'serving_size': '150g',
              'nutriments': {
                'energy-kcal_serving': 120,
                'proteins_serving': 10,
                'carbohydrates_serving': 15,
                'fat_serving': 3,
              },
              'code': '123',
              'brands': 'Danone',
            }
          ]}),
          200,
        )),
      );
      final service = FoodSearchService(db: db, apiClient: mockApiClient);
      FoodSearchItem? returnedItem;

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
                onPressed: () async {
                  returnedItem = await showSearch<FoodSearchItem?>(
                    context: context,
                    delegate: FoodSearchDelegate(
                      searchService: service,
                      apiClient: mockApiClient,
                      onCreateCustomFood: (context, {existingFood}) async {
                        return await Navigator.of(context).push<Food>(
                          MaterialPageRoute(
                            builder: (_) => ProviderScope(
                              overrides: [
                                databaseProvider.overrideWithValue(db),
                              ],
                              child: ManualFoodForm(existingFood: existingFood),
                            ),
                          ),
                        );
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

      // Switch to web search, search, tap result
      await tester.tap(find.text('Search the Web'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'yogurt');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Test Yogurt'));
      await tester.pumpAndSettle();

      // Fill in required fields that might not be pre-filled
      // The form should have pre-filled values, just save
      final saveButton = find.text('Save');
      await tester.dragUntilVisible(
        saveButton,
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Delegate should have closed and returned the food
      expect(returnedItem, isNotNull);
      expect(returnedItem!.name, 'Test Yogurt');

      // Food should be in the database
      final foods = await (db.select(db.foods)).get();
      expect(foods.length, 1);
      expect(foods.first.name, 'Test Yogurt');
      expect(foods.first.source, 'open_food_facts');
    });

    testWidgets('cancel web food form does not save', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response(
          jsonEncode({'products': [
            {
              'product_name': 'Test Yogurt',
              'serving_size': '150g',
              'nutriments': {
                'energy-kcal_serving': 120,
                'proteins_serving': 10,
                'carbohydrates_serving': 15,
                'fat_serving': 3,
              },
              'code': '123',
            }
          ]}),
          200,
        )),
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
                      onCreateCustomFood: (context, {existingFood}) async {
                        return await Navigator.of(context).push<Food>(
                          MaterialPageRoute(
                            builder: (_) => ProviderScope(
                              overrides: [
                                databaseProvider.overrideWithValue(db),
                              ],
                              child: ManualFoodForm(existingFood: existingFood),
                            ),
                          ),
                        );
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

      await tester.tap(find.text('Search the Web'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'yogurt');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Test Yogurt'));
      await tester.pumpAndSettle();

      // Cancel by pressing back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // No food should be saved
      final foods = await (db.select(db.foods)).get();
      expect(foods, isEmpty);
    });
  });
}
