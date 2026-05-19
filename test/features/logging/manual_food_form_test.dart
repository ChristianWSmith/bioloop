import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/logging/widgets/manual_food_form.dart';
import 'package:bioloop/providers/database_provider.dart';

void main() {
  group('ManualFoodForm', () {
    AppDatabase createDb() => AppDatabase.createInMemory();

    Future<void> pushForm(WidgetTester tester, AppDatabase db) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProviderScope(
                    overrides: [databaseProvider.overrideWithValue(db)],
                    child: const ManualFoodForm(),
                  ),
                ),
              ),
              child: const Text('Open Form'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();
    }

    Future<void> fillRequiredFields(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).at(0), 'Test Food');
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.enterText(find.byType(TextFormField).at(3), '200');
      await tester.enterText(find.byType(TextFormField).at(4), '10');
      await tester.enterText(find.byType(TextFormField).at(5), '20');
      await tester.enterText(find.byType(TextFormField).at(6), '5');
    }

    Future<void> tapSave(WidgetTester tester) async {
      final saveButton = find.text('Save');
      await tester.dragUntilVisible(
        saveButton,
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pump();
      await tester.tap(saveButton);
    }

    testWidgets('validation: empty name shows error', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.enterText(find.byType(TextFormField).at(3), '200');
      await tester.enterText(find.byType(TextFormField).at(4), '10');
      await tester.enterText(find.byType(TextFormField).at(5), '20');
      await tester.enterText(find.byType(TextFormField).at(6), '5');

      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('Custom Food'), findsOneWidget);
    });

    testWidgets('validation: negative calories shows error', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await tester.enterText(find.byType(TextFormField).at(0), 'Test Food');
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.enterText(find.byType(TextFormField).at(3), '-1');

      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('Custom Food'), findsOneWidget);
    });

    testWidgets('save: creates food with source=manual and barcode=null',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await fillRequiredFields(tester);

      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('Open Form'), findsOneWidget);
      expect(find.text('Custom Food'), findsNothing);

      final foods = await (db.select(db.foods)).get();
      expect(foods.length, 1);
      expect(foods.first.name, 'Test Food');
      expect(foods.first.source, 'manual');
      expect(foods.first.barcode, isNull);
    });

    testWidgets('cancel: pops without saving', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Open Form'), findsOneWidget);
      expect(find.text('Custom Food'), findsNothing);

      final foods = await (db.select(db.foods)).get();
      expect(foods, isEmpty);
    });

    testWidgets('optional gram weight: empty does not block save',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await fillRequiredFields(tester);

      await tapSave(tester);
      await tester.pumpAndSettle();

      final foods = await (db.select(db.foods)).get();
      expect(foods.length, 1);
    });

    testWidgets(
        'field defaults: macros start empty, quantity defaults to 1, unit shows g',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      expect(
          find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
      expect(
          find.widgetWithText(TextFormField, 'Quantity'), findsOneWidget);
      expect(
          find.widgetWithText(TextFormField, 'Calories per serving'),
          findsOneWidget);
      expect(
          find.widgetWithText(TextFormField, 'Protein per serving (g)'),
          findsOneWidget);
      expect(
          find.widgetWithText(TextFormField, 'Carbs per serving (g)'),
          findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Fat per serving (g)'),
          findsOneWidget);

      expect(find.text('Label: 1 g'), findsOneWidget);

      final caloriesField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Calories per serving'),
          matching: find.byType(TextField),
        ),
      );
      expect(caloriesField.controller?.text, '');
    });

    testWidgets('integration: created food appears in local search',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await fillRequiredFields(tester);

      await tapSave(tester);
      await tester.pumpAndSettle();

      final results = await db.searchByName('Test');
      expect(results.length, 1);
      expect(results.first.name, 'Test Food');
      expect(results.first.source, 'manual');
    });

    testWidgets('auto-compute calories from protein/carbs/fat',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await tester.enterText(find.byType(TextFormField).at(0), 'Test');
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.enterText(find.byType(TextFormField).at(4), '20');
      await tester.enterText(find.byType(TextFormField).at(5), '30');
      await tester.enterText(find.byType(TextFormField).at(6), '10');

      final caloriesField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Calories per serving'),
          matching: find.byType(TextField),
        ),
      );
      expect(caloriesField.controller?.text, '290');
    });

    testWidgets('manual calorie value recalculates when macros change',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await tester.enterText(find.byType(TextFormField).at(0), 'Test');
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.enterText(find.byType(TextFormField).at(4), '20');
      await tester.enterText(find.byType(TextFormField).at(5), '30');
      await tester.enterText(find.byType(TextFormField).at(6), '10');

      // Manually set calories
      await tester.enterText(find.byType(TextFormField).at(3), '300');

      // Change a macro — calories should recalculate automatically
      await tester.enterText(find.byType(TextFormField).at(4), '25');

      // 25*4 + 30*4 + 10*9 = 100 + 120 + 90 = 310
      final caloriesField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Calories per serving'),
          matching: find.byType(TextField),
        ),
      );
      expect(caloriesField.controller?.text, '310');
    });

    testWidgets('auto-compute resumes after clearing all macros',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await tester.enterText(find.byType(TextFormField).at(0), 'Test');
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.enterText(find.byType(TextFormField).at(4), '20');
      await tester.enterText(find.byType(TextFormField).at(5), '30');
      await tester.enterText(find.byType(TextFormField).at(6), '10');

      await tester.enterText(find.byType(TextFormField).at(3), '300');

      await tester.enterText(find.byType(TextFormField).at(4), '');
      await tester.enterText(find.byType(TextFormField).at(5), '');
      await tester.enterText(find.byType(TextFormField).at(6), '');

      await tester.enterText(find.byType(TextFormField).at(4), '10');
      await tester.enterText(find.byType(TextFormField).at(5), '10');
      await tester.enterText(find.byType(TextFormField).at(6), '10');

      final caloriesField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Calories per serving'),
          matching: find.byType(TextField),
        ),
      );
      expect(caloriesField.controller?.text, '170');
    });

    testWidgets('brand field: save with brand stores it in DB', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await tester.enterText(find.byType(TextFormField).at(0), 'Brand Food');
      await tester.enterText(find.byType(TextFormField).at(1), 'Acme');
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.enterText(find.byType(TextFormField).at(3), '200');
      await tester.enterText(find.byType(TextFormField).at(4), '10');
      await tester.enterText(find.byType(TextFormField).at(5), '20');
      await tester.enterText(find.byType(TextFormField).at(6), '5');

      await tapSave(tester);
      await tester.pumpAndSettle();

      final foods = await (db.select(db.foods)).get();
      expect(foods.length, 1);
      expect(foods.first.brand, 'Acme');
    });

    testWidgets('brand field: save without brand stores null', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pushForm(tester, db);

      await fillRequiredFields(tester);

      await tapSave(tester);
      await tester.pumpAndSettle();

      final foods = await (db.select(db.foods)).get();
      expect(foods.length, 1);
      expect(foods.first.brand, isNull);
    });

    testWidgets('brand field: edit pre-fills brand', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Existing Food',
        servingLabel: '100g',
        caloriesPerServing: 200,
        proteinPerServing: 10,
        carbsPerServing: 20,
        fatPerServing: 5,
        brand: Value('BrandX'),
        createdAt: now,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProviderScope(
                    overrides: [databaseProvider.overrideWithValue(db)],
                    child: ManualFoodForm(
                      existingFood: Food(
                        id: 1,
                        name: 'Existing Food',
                        servingLabel: '100g',
                        servingQuantity: 100,
                        servingUnit: 'g',
                        caloriesPerServing: 200,
                        proteinPerServing: 10,
                        carbsPerServing: 20,
                        fatPerServing: 5,
                        barcode: null,
                        brand: 'BrandX',
                        source: 'manual',
                        createdAt: now,
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open Form'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Food'), findsOneWidget);

      final brandField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Brand (optional)'),
          matching: find.byType(TextField),
        ),
      );
      expect(brandField.controller?.text, 'BrandX');
    });

    testWidgets('brand field: clearing brand saves null', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Existing Food',
        servingLabel: '100g',
        caloriesPerServing: 200,
        proteinPerServing: 10,
        carbsPerServing: 20,
        fatPerServing: 5,
        brand: Value('BrandX'),
        createdAt: now,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProviderScope(
                    overrides: [databaseProvider.overrideWithValue(db)],
                    child: ManualFoodForm(
                      existingFood: Food(
                        id: 1,
                        name: 'Existing Food',
                        servingLabel: '100g',
                        servingQuantity: 100,
                        servingUnit: 'g',
                        caloriesPerServing: 200,
                        proteinPerServing: 10,
                        carbsPerServing: 20,
                        fatPerServing: 5,
                        barcode: null,
                        brand: 'BrandX',
                        source: 'manual',
                        createdAt: now,
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open Form'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      // Clear the brand field
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Brand (optional)'),
        '',
      );

      await tapSave(tester);
      await tester.pumpAndSettle();

      final foods = await (db.select(db.foods)).get();
      expect(foods.length, 1);
      expect(foods.first.brand, isNull);
    });
  });
}
