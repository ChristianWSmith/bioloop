import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/bodyweight/bodyweight_screen.dart';
import 'package:bioloop/providers/database_provider.dart';

void main() {
  group('BodyweightScreen', () {
    AppDatabase createDb() => AppDatabase.createInMemory();

    Future<void> pumpScreen(WidgetTester tester, AppDatabase db) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: Scaffold(body: BodyweightScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sheet opens: tapping Log weight shows bottom sheet',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      await tester.tap(find.byKey(const Key('log_weight_button')));
      await tester.pumpAndSettle();

      expect(find.text('Log weight'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('validation: empty weight disables save button',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      await tester.tap(find.byKey(const Key('log_weight_button')));
      await tester.pumpAndSettle();

      final button =
          tester.widget<FilledButton>(find.byKey(const Key('save_weight_button')));
      expect(button.onPressed, isNull);
    });

    testWidgets('validation: non-numeric input shows error text',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      await tester.tap(find.byKey(const Key('log_weight_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Enter a valid weight'), findsOneWidget);
    });

    testWidgets('save: creates entry and shows in list', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      await tester.tap(find.byKey(const Key('log_weight_button')));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const Key('save_weight_button')), findsOneWidget);

      // Verify button is disabled before entering text
      var saveBtn = tester.widget<FilledButton>(
        find.byKey(const Key('save_weight_button')),
      );
      expect(saveBtn.onPressed, isNull);

      await tester.enterText(find.byType(TextField), '75.5');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify text was entered and button is enabled
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '75.5');

      saveBtn = tester.widget<FilledButton>(
        find.byKey(const Key('save_weight_button')),
      );
      expect(saveBtn.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('save_weight_button')));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final entries = await db.select(db.bodyweightEntries).get();
      expect(entries.length, 1);
      expect(entries.first.weightKg, 75.5);

      expect(find.text('75.5 kg'), findsOneWidget);
    });

    testWidgets('edit: tap entry opens sheet pre-filled', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();
      await db.into(db.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(weightKg: 75.5, loggedAt: now),
          );

      await pumpScreen(tester, db);
      expect(find.text('75.5 kg'), findsOneWidget);

      await tester.tap(find.text('75.5 kg'));
      await tester.pumpAndSettle();

      expect(find.text('Edit weight'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '75.5');
    });

    testWidgets('edit save: update weight reflects in list',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();
      await db.into(db.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(weightKg: 75.5, loggedAt: now),
          );

      await pumpScreen(tester, db);
      await tester.tap(find.text('75.5 kg'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '80.0');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('save_weight_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('80.0 kg'), findsOneWidget);
      expect(find.text('75.5 kg'), findsNothing);

      final entries = await db.select(db.bodyweightEntries).get();
      expect(entries.length, 1);
      expect(entries.first.weightKg, 80.0);
    });

    testWidgets('delete: long-press removes entry', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();
      await db.into(db.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(weightKg: 75.5, loggedAt: now),
          );

      await pumpScreen(tester, db);
      expect(find.text('75.5 kg'), findsOneWidget);

      await tester.longPress(find.text('75.5 kg'));
      await tester.pumpAndSettle();

      expect(find.text('Delete entry?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('75.5 kg'), findsNothing);
      expect(find.text('No entries yet'), findsOneWidget);

      final entries = await db.select(db.bodyweightEntries).get();
      expect(entries, isEmpty);
    });

    testWidgets('keyboard type: weight field uses decimal numeric',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpScreen(tester, db);

      await tester.tap(find.byKey(const Key('log_weight_button')));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType,
          const TextInputType.numberWithOptions(decimal: true));
    });
  });

  group('BodyweightService', () {
    test('provider: returns entries sorted by logged_at descending',
        () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.into(db.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(
                weightKg: 70.0, loggedAt: '2026-05-10'),
          );
      await db.into(db.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(
                weightKg: 75.0, loggedAt: '2026-05-12'),
          );
      await db.into(db.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(
                weightKg: 72.5, loggedAt: '2026-05-11'),
          );

      final weights = await db.getWeights();
      expect(weights.length, 3);
      expect(weights[0].weightKg, 75.0);
      expect(weights[1].weightKg, 72.5);
      expect(weights[2].weightKg, 70.0);
    });

    test('date backfill: past dates appear in full query', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.into(db.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(
                weightKg: 75.0, loggedAt: '2026-05-12'),
          );
      await db.into(db.bodyweightEntries).insert(
            BodyweightEntriesCompanion.insert(
                weightKg: 74.0, loggedAt: '2026-05-11'),
          );

      final allWeights = await db.getWeights();
      expect(allWeights.length, 2);

      final todayWeights =
          await db.getWeights(since: DateTime(2026, 5, 12));
      expect(todayWeights.length, 1);
      expect(todayWeights.first.weightKg, 75.0);
    });
  });
}
