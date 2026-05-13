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
import 'package:bioloop/features/logging/widgets/meal_templates.dart';
import 'package:bioloop/providers/database_provider.dart';
import 'package:bioloop/providers/food_search_provider.dart';

void main() {
  group('TemplateFood serialization', () {
    test('round-trip JSON', () {
      final original = TemplateFood(
        name: 'Oats',
        calories: 389,
        proteinGrams: 16.9,
        carbsGrams: 66.3,
        fatGrams: 6.9,
        servings: 1,
        servingLabel: '100g',
      );
      final json = original.toJson();
      final restored = TemplateFood.fromJson(json);
      expect(restored.name, original.name);
      expect(restored.calories, original.calories);
      expect(restored.servings, original.servings);
    });
  });

  group('encodeTemplateFoods / parse', () {
    test('encode then decode returns same data', () {
      final foods = [
        TemplateFood(
          name: 'Oats',
          calories: 389,
          proteinGrams: 16.9,
          carbsGrams: 66.3,
          fatGrams: 6.9,
          servings: 1,
          servingLabel: '100g',
        ),
        TemplateFood(
          name: 'Milk',
          calories: 150,
          proteinGrams: 8,
          carbsGrams: 12,
          fatGrams: 8,
          servings: 1,
          servingLabel: '1 cup',
        ),
      ];
      final encoded = encodeTemplateFoods(foods);
      final decoded = jsonDecode(encoded) as List<dynamic>;
      expect(decoded.length, 2);

      final restored =
          decoded.map((e) => TemplateFood.fromJson(e)).toList();
      expect(restored[0].name, 'Oats');
      expect(restored[1].name, 'Milk');
    });
  });

  group('MealTemplatesSheet', () {
    Future<void> pumpSheet(
        WidgetTester tester, AppDatabase db) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ProviderScope(
                    overrides: [
                      databaseProvider.overrideWithValue(db),
                    ],
                    child: const MealTemplatesSheet(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows empty state when no templates', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await pumpSheet(tester, db);

      expect(find.text('Meal Templates'), findsOneWidget);
      expect(find.text('No templates yet'), findsOneWidget);
      expect(
        find.byKey(const Key('empty_state_log_food')),
        findsOneWidget,
      );
      expect(find.text('Log a food'), findsOneWidget);
    });

    testWidgets('empty state button closes the sheet', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await pumpSheet(tester, db);

      expect(find.text('Meal Templates'), findsOneWidget);
      await tester.tap(find.byKey(const Key('empty_state_log_food')));
      await tester.pumpAndSettle();

      expect(find.text('Meal Templates'), findsNothing);
    });

    testWidgets('shows saved template name and food count',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.insertTemplate(MealTemplatesCompanion.insert(
        name: 'My Breakfast',
        foods: jsonEncode([
          {
            'name': 'Oats',
            'calories': 389,
            'protein_grams': 16.9,
            'carbs_grams': 66.3,
            'fat_grams': 6.9,
            'servings': 1,
            'serving_label': '100g',
          },
          {
            'name': 'Milk',
            'calories': 150,
            'protein_grams': 8,
            'carbs_grams': 12,
            'fat_grams': 8,
            'servings': 1,
            'serving_label': '1 cup',
          },
        ]),
        createdAt: DateTime.now().toIso8601String(),
      ));

      await pumpSheet(tester, db);

      expect(find.text('My Breakfast'), findsOneWidget);
      expect(find.text('2 foods'), findsOneWidget);
    });
  });

  group('LogFoodScreen templates integration', () {
    AppDatabase createSeedDb() {
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

    OpenFoodFactsClient createMockApi() {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode({'products': []}), 200);
      });
      return OpenFoodFactsClient(client: mock);
    }

    Future<void> pumpScreen(WidgetTester tester, AppDatabase db) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            openFoodFactsClientProvider.overrideWithValue(
              createMockApi(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: LogFoodScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('templates button is visible', (tester) async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      expect(
        find.byKey(const Key('templates_button')),
        findsOneWidget,
      );
      expect(find.text('Templates'), findsOneWidget);
    });

    testWidgets('save as template button appears when food selected',
        (tester) async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      expect(
        find.byKey(const Key('save_as_template_button')),
        findsNothing,
      );

      // Select a food via search
      await tester.tap(find.byKey(const Key('food_search_field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && !w.readOnly),
        'Chicken',
      );
      await tester.pump();
      // Wait for debounce (400ms) + search to complete
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Chicken Breast').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
        find.byKey(const Key('save_as_template_button')),
        findsOneWidget,
      );
    });

    test('DAO: insert and getAllTemplates round-trip', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.insertTemplate(MealTemplatesCompanion.insert(
        name: 'Morning Oats',
        foods: jsonEncode([
          {
            'name': 'Oats',
            'calories': 389,
            'protein_grams': 16.9,
            'carbs_grams': 66.3,
            'fat_grams': 6.9,
            'servings': 1.0,
            'serving_label': '100g',
          },
        ]),
        createdAt: DateTime.now().toIso8601String(),
      ));

      final templates = await db.getAllTemplates();
      expect(templates.length, 1);
      expect(templates.first.name, 'Morning Oats');

      final foods = jsonDecode(templates.first.foods) as List<dynamic>;
      expect(foods.length, 1);
      expect(foods.first['name'], 'Oats');
    });

    test('DAO: delete template removes row', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final id = await db.insertTemplate(MealTemplatesCompanion.insert(
        name: 'Test',
        foods: '[]',
        createdAt: DateTime.now().toIso8601String(),
      ));

      expect((await db.getAllTemplates()).length, 1);
      await db.deleteTemplate(id);
      expect((await db.getAllTemplates()).length, 0);
    });

    test('DAO: update template modifies row', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final id = await db.insertTemplate(MealTemplatesCompanion.insert(
        name: 'Old Name',
        foods: '[]',
        createdAt: DateTime.now().toIso8601String(),
      ));

      await db.updateTemplate(id, MealTemplatesCompanion(
        name: const Value('New Name'),
      ));

      final t = await db.getTemplate(id);
      expect(t?.name, 'New Name');
    });

    testWidgets('save as template button visible when food selected',
        (tester) async {
      final db = createSeedDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      await tester.tap(find.byKey(const Key('food_search_field')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && !w.readOnly),
        'Chicken',
      );
      await tester.pump();
      // Wait for debounce (400ms) + search to complete
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Chicken Breast').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(
        find.byKey(const Key('save_as_template_button')),
        findsOneWidget,
      );
    });
  });
}
