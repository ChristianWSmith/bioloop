import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bioloop/core/api/open_food_facts_client.dart';
import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/logging/log_food_screen.dart';
import 'package:bioloop/providers/database_provider.dart';
import 'package:bioloop/providers/food_search_provider.dart';

AppDatabase _createSeedDb() {
  final db = AppDatabase.createInMemory();
  final now = DateTime.now().toIso8601String();
  db.into(db.foods).insert(FoodsCompanion.insert(
    name: 'Oats',
    servingLabel: '100g',
    servingSizeGrams: Value(100),
    caloriesPerServing: 389,
    proteinPerServing: 16.9,
    carbsPerServing: 66.3,
    fatPerServing: 6.9,
    barcode: Value('987'),
    createdAt: now,
  ));
  db.into(db.foods).insert(FoodsCompanion.insert(
    name: 'Chicken Breast',
    servingLabel: '100g',
    servingSizeGrams: Value(100),
    caloriesPerServing: 165,
    proteinPerServing: 31,
    carbsPerServing: 0,
    fatPerServing: 3.6,
    createdAt: now,
  ));
  return db;
}

OpenFoodFactsClient _createMockApi({List<Map<String, dynamic>>? products}) {
  final mock = MockClient((_) async {
    return http.Response(jsonEncode({
      'products': products ?? [],
    }), 200);
  });
  return OpenFoodFactsClient(client: mock);
}

Finder _editableTextField() => find.byWidgetPredicate(
      (w) => w is TextField && !w.readOnly,
    );

void main() {
  group('LogFoodScreen', () {
    Future<void> pumpScreen(WidgetTester tester, AppDatabase db,
        {OpenFoodFactsClient? apiClient}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            openFoodFactsClientProvider.overrideWithValue(
              apiClient ?? _createMockApi(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: LogFoodScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Open search delegate, type a query, tap the result label, and wait
    /// for the route to fully pop.
    Future<void> searchAndTapResult(
        WidgetTester tester, String query, String resultLabel) async {
      await tester.tap(find.byKey(const Key('food_search_field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(_editableTextField(), query);
      await tester.pump();
      // Fire debounce timer (400ms) + let search future complete
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text(resultLabel).last);
      // Wait for route pop animation (300ms default) to fully complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }

    Future<void> selectFood(WidgetTester tester) =>
        searchAndTapResult(tester, 'Chicken', 'Chicken Breast');

    testWidgets('empty state shows no entries today text', (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      expect(
        find.text('No entries logged today'),
        findsOneWidget,
      );
    });

    testWidgets('search delegate: typing shows results', (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      await tester.tap(find.byKey(const Key('food_search_field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(_editableTextField(), 'Oats');
      await tester.pump();
      // Wait for debounce (400ms) + search to complete
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();

      expect(find.text('Oats'), findsAtLeastNWidgets(1));
      expect(find.text('Create custom food'), findsOneWidget);
    });

    testWidgets('search debounce delays results until typing stops',
        (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      await tester.tap(find.byKey(const Key('food_search_field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Type a single character and advance only 100ms (before debounce fires)
      await tester.enterText(_editableTextField(), 'C');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Results should NOT be showing yet (debounce timer hasn't fired)
      expect(find.text('Chicken Breast'), findsNothing);

      // Wait for debounce to fire + search to complete
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();

      // Now results should appear
      expect(find.text('Chicken Breast'), findsWidgets);
    });

    testWidgets('closing search before debounce fires does not crash',
        (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      await tester.tap(find.byKey(const Key('food_search_field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Type text and close before debounce fires
      await tester.enterText(_editableTextField(), 'Chicken');
      await tester.pump();

      // Close search immediately
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Should be back on log screen without crash
      expect(
        find.text('No entries logged today'),
        findsOneWidget,
      );
    });

    testWidgets('quantity input: typing doubles macros',
        (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);
      await selectFood(tester);

      expect(find.text('165'), findsOneWidget);

      // After selectFood the only editable TextField is the quantity input
      await tester.enterText(_editableTextField(), '2');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('330'), findsOneWidget);

      await tester.enterText(_editableTextField(), '3');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('495'), findsOneWidget);
    });

    testWidgets(
        'quantity input: fractional value scales macros correctly',
        (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);
      await selectFood(tester);

      await tester.enterText(_editableTextField(), '1.5');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('248'), findsOneWidget);
    });

    testWidgets(
        'meal type selector: tap selects, Save disabled until selected',
        (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);
      await selectFood(tester);

      final saveButton =
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNull);

      await tester.tap(find.text('Lunch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final saveButton2 =
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton2.onPressed, isNotNull);
    });

    testWidgets('save creates food_entries row with scaled macros',
        (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);
      await selectFood(tester);

      await tester.tap(find.text('Lunch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final entries = await db.select(db.foodEntries).get();
      expect(entries.length, 1);
      expect(entries.first.name, 'Chicken Breast');
      expect(entries.first.calories, 165);
      expect(entries.first.proteinGrams, 31);
      expect(entries.first.carbsGrams, 0);
      expect(entries.first.fatGrams, 3.6);
      expect(entries.first.servings, 1);
      expect(entries.first.mealType, 'lunch');
      expect(entries.first.foodId, isNotNull);
    });

    testWidgets('API food auto-caches to foods table on save',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await pumpScreen(
        tester,
        db,
        apiClient: _createMockApi(products: [
          {
            'product_name': 'API Oats',
            'nutriments': {
              'energy-kcal_serving': 389,
              'proteins_serving': 16.9,
              'carbohydrates_serving': 66.3,
              'fat_serving': 6.9,
            },
            'code': 'api-123',
          },
        ]),
      );

      await searchAndTapResult(tester, 'Oats', 'API Oats');

      await tester.tap(find.text('Breakfast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final foods = await db.select(db.foods).get();
      expect(foods.length, 1);
      expect(foods.first.name, 'API Oats');
      expect(foods.first.source, 'open_food_facts');
      expect(foods.first.barcode, 'api-123');
    });

    testWidgets('save error shows dialog', (tester) async {
      final db = AppDatabase.createInMemory();
      final now = DateTime.now().toIso8601String();
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Test Food',
        servingLabel: '1 serving',
        caloriesPerServing: 100,
        proteinPerServing: 10,
        carbsPerServing: 10,
        fatPerServing: 5,
        createdAt: now,
      ));

      await pumpScreen(tester, db);
      await searchAndTapResult(tester, 'Test', 'Test Food');

      await tester.tap(find.text('Dinner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await db.close();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('Failed to save'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Error'), findsNothing);
    });

    testWidgets('clear selection resets state', (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);
      await selectFood(tester);

      final searchField = tester.widget<TextField>(
        find.byKey(const Key('food_search_field')),
      );
      final decoration = searchField.decoration as InputDecoration;
      expect(decoration.hintText, 'Chicken Breast');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('No entries logged today'),
        findsOneWidget,
      );
    });

    testWidgets('two saves create two separate entries', (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      // First save
      await selectFood(tester);
      await tester.tap(find.text('Lunch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Food logged!'), findsOneWidget);

      // Let snackbar fully auto-dismiss before second save
      await tester.pumpAndSettle();

      // Second save — invoke onPressed directly since the button
      // is at the very bottom edge of the 600px test viewport
      await searchAndTapResult(tester, 'Chicken', 'Chicken Breast');
      await tester.tap(find.text('Dinner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
      button.onPressed!();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final entries = await db.select(db.foodEntries).get();
      expect(entries.length, 2);
    });

    testWidgets(
        'macro scaling: all four macros match food.macro × servings',
        (tester) async {
      final db = _createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);
      await selectFood(tester);

      expect(find.text('165'), findsOneWidget);
      expect(find.textContaining('31.0'), findsAtLeastNWidgets(1));
      expect(find.textContaining('0.0'), findsAtLeastNWidgets(1));
      expect(find.textContaining('3.6'), findsAtLeastNWidgets(1));

      // 2 servings
      await tester.enterText(_editableTextField(), '2');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('330'), findsOneWidget);
      expect(find.textContaining('62.0'), findsAtLeastNWidgets(1));
      expect(find.textContaining('0.0'), findsAtLeastNWidgets(1));
      expect(find.textContaining('7.2'), findsAtLeastNWidgets(1));
    });
  });
}
