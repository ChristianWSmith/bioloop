import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/history/history_screen.dart';
import 'package:bioloop/providers/database_provider.dart';

Future<int> _insertEntry(
  AppDatabase db, {
  required String name,
  double calories = 500,
  double protein = 30,
  double carbs = 50,
  double fat = 20,
  double servings = 1,
  String mealType = 'lunch',
  required String loggedAt,
}) async {
  return await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
    name: name,
    calories: calories,
    proteinGrams: protein,
    carbsGrams: carbs,
    fatGrams: fat,
    servings: servings,
    servingLabel: 'serving',
    mealType: mealType,
    loggedAt: loggedAt,
  ));
}

void main() {
  group('HistoryScreen', () {
    AppDatabase createDb() => AppDatabase.createInMemory();

    Future<void> pumpScreen(WidgetTester tester, AppDatabase db) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: Scaffold(body: HistoryScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('empty state: shows no food message', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      expect(find.text('No food logged yet'), findsOneWidget);
    });

    testWidgets('date grouping: entries from 3 dates render as 3 sections',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      await _insertEntry(db,
          name: 'Meal 1', loggedAt: '${fmt(twoDaysAgo)}T08:00:00');
      await _insertEntry(db,
          name: 'Meal 2', loggedAt: '${fmt(yesterday)}T12:00:00');
      await _insertEntry(db,
          name: 'Meal 3', loggedAt: '${fmt(today)}T18:00:00');

      await pumpScreen(tester, db);

      const monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      expect(
        find.text(
            '${monthNames[twoDaysAgo.month - 1]} ${twoDaysAgo.day}, ${twoDaysAgo.year}'),
        findsOneWidget,
      );
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Meal 1'), findsOneWidget);
      expect(find.text('Meal 2'), findsOneWidget);
      expect(find.text('Meal 3'), findsOneWidget);
    });

    testWidgets('swipe-to-delete: entry removed after confirmation',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      await _insertEntry(db,
          name: 'Test Meal', loggedAt: '2026-05-12T10:00:00');

      await pumpScreen(tester, db);

      expect(find.text('Test Meal'), findsOneWidget);

      await tester.drag(find.text('Test Meal'), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delete entry?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Meal'), findsNothing);
      expect(find.text('No food logged yet'), findsOneWidget);

      final entries = await db.select(db.foodEntries).get();
      expect(entries, isEmpty);
    });

    testWidgets('cancel delete: entry remains after cancel',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      await _insertEntry(db,
          name: 'Test Meal', loggedAt: '2026-05-12T10:00:00');

      await pumpScreen(tester, db);

      await tester.drag(find.text('Test Meal'), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delete entry?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Meal'), findsOneWidget);
      expect(find.text('No food logged yet'), findsNothing);

      final entries = await db.select(db.foodEntries).get();
      expect(entries.length, 1);
    });

    testWidgets('tap-to-edit: opens edit bottom sheet with pre-filled values',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      await _insertEntry(db,
          name: 'Oatmeal',
          calories: 300,
          protein: 10,
          carbs: 50,
          fat: 5,
          servings: 1,
          mealType: 'breakfast',
          loggedAt: '2026-05-12T07:30:00');

      await pumpScreen(tester, db);

      await tester.tap(find.text('Oatmeal'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Edit entry'), findsOneWidget);
      expect(find.byKey(const Key('edit_name_field')), findsOneWidget);

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('edit_name_field')),
      );
      expect(nameField.controller?.text, 'Oatmeal');
    });

    testWidgets('edit save: change name, entry reflects new values',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      await _insertEntry(db,
          name: 'Oatmeal',
          calories: 300,
          protein: 10,
          carbs: 50,
          fat: 5,
          servings: 1,
          mealType: 'breakfast',
          loggedAt: '2026-05-12T07:30:00');

      await pumpScreen(tester, db);

      await tester.tap(find.text('Oatmeal'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Change name
      await tester.enterText(
        find.byKey(const Key('edit_name_field')),
        'Granola',
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Save
      await tester.tap(find.byKey(const Key('save_edit_button')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Granola'), findsOneWidget);
      expect(find.text('Oatmeal'), findsNothing);

      final entries = await db.select(db.foodEntries).get();
      expect(entries.length, 1);
      expect(entries.first.name, 'Granola');
    });

    testWidgets('edit macro scaling: servings 1.0 -> 2.0 doubles macros',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      await _insertEntry(db,
          name: 'Test Meal',
          calories: 300,
          protein: 10,
          carbs: 50,
          fat: 5,
          servings: 1,
          mealType: 'lunch',
          loggedAt: '2026-05-12T12:00:00');

      await pumpScreen(tester, db);

      await tester.tap(find.text('Test Meal'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Change servings to 2
      await tester.enterText(
        find.byKey(const Key('edit_servings_field')),
        '2',
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Save
      await tester.tap(find.byKey(const Key('save_edit_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final entries = await db.select(db.foodEntries).get();
      expect(entries.length, 1);
      expect(entries.first.calories, closeTo(600, 0.1));
      expect(entries.first.proteinGrams, closeTo(20, 0.1));
      expect(entries.first.carbsGrams, closeTo(100, 0.1));
      expect(entries.first.fatGrams, closeTo(10, 0.1));
    });

    testWidgets('edit macro scaling: change servings back to 1 restores original',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      await _insertEntry(db,
          name: 'Test Meal',
          calories: 300,
          protein: 10,
          carbs: 50,
          fat: 5,
          servings: 1,
          mealType: 'lunch',
          loggedAt: '2026-05-12T12:00:00');

      await pumpScreen(tester, db);

      await tester.tap(find.text('Test Meal'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Change servings to 2
      await tester.enterText(
        find.byKey(const Key('edit_servings_field')),
        '2',
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Change back to 1
      await tester.enterText(
        find.byKey(const Key('edit_servings_field')),
        '1',
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('save_edit_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final entries = await db.select(db.foodEntries).get();
      expect(entries.length, 1);
      expect(entries.first.calories, closeTo(300, 0.1));
      expect(entries.first.proteinGrams, closeTo(10, 0.1));
      expect(entries.first.carbsGrams, closeTo(50, 0.1));
      expect(entries.first.fatGrams, closeTo(5, 0.1));
    });

    testWidgets('pull-to-refresh: pull down triggers reload',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      // Insert an entry so the RefreshIndicator is present
      await _insertEntry(db,
          name: 'Initial Meal', loggedAt: '2026-05-12T10:00:00');

      await pumpScreen(tester, db);
      expect(find.text('Initial Meal'), findsOneWidget);

      // Insert another entry after initial load
      await _insertEntry(db,
          name: 'Late Meal', loggedAt: '2026-05-12T18:00:00');

      // Pull to refresh via drag from the top of the list
      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, 300),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Late Meal should be visible (sorted first by loggedAt desc)
      expect(find.text('Late Meal'), findsOneWidget);
      expect(find.text('Initial Meal'), findsOneWidget);
    });

    testWidgets('pagination: 25 entries load 20 initially, scroll loads 5 more',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      for (int i = 1; i <= 25; i++) {
        await _insertEntry(db,
            name: 'Entry ${i.toString().padLeft(2, '0')}',
            loggedAt:
                '2026-05-12T${i.toString().padLeft(2, '0')}:00:00');
      }

      await pumpScreen(tester, db);

      // Sorted DESC: Entry 25 (1st) ... Entry 6 (20th) on first page.
      // Entry 5+ are in the second page.
      expect(find.text('Entry 25'), findsOneWidget);
      expect(find.text('Entry 05'), findsNothing);

      // Scroll near the bottom to trigger pagination
      await tester.scrollUntilVisible(
        find.text('Entry 05'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Entry 05 should now be visible
      expect(find.text('Entry 05'), findsOneWidget);
    });

    testWidgets('entry details: shows name, macros, meal type, time',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      await _insertEntry(db,
          name: 'Chicken Rice',
          calories: 650,
          protein: 45,
          carbs: 70,
          fat: 15,
          servings: 1,
          mealType: 'dinner',
          loggedAt: '2026-05-12T19:30:00');

      await pumpScreen(tester, db);

      expect(find.text('Chicken Rice'), findsOneWidget);
      expect(find.textContaining('650 cal'), findsOneWidget);
      expect(find.textContaining('P45g'), findsOneWidget);
      expect(find.textContaining('C70g'), findsOneWidget);
      expect(find.textContaining('F15g'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.textContaining('19:30'), findsOneWidget);
    });
  });

  group('Pagination DAO', () {
    test('getEntriesPaginated returns correct slices', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      for (int i = 1; i <= 25; i++) {
        await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
          name: 'Entry $i',
          calories: 100.0,
          proteinGrams: 10.0,
          carbsGrams: 10.0,
          fatGrams: 5.0,
          servings: 1,
          servingLabel: 'serving',
          mealType: 'snack',
          loggedAt: '2026-05-12T${i.toString().padLeft(2, '0')}:00:00',
        ));
      }

      final firstPage = await db.getEntriesPaginated(offset: 0, limit: 20);
      expect(firstPage.length, 20);

      final secondPage = await db.getEntriesPaginated(offset: 20, limit: 20);
      expect(secondPage.length, 5);

      expect(firstPage[0].name, 'Entry 25');
      expect(firstPage[19].name, 'Entry 6');
      expect(secondPage[0].name, 'Entry 5');
      expect(secondPage[4].name, 'Entry 1');
    });
  });
}
