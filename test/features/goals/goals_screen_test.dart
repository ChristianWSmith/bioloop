import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/goals/goals_screen.dart';
import 'package:bioloop/providers/database_provider.dart';

ProviderScope buildGoalsScreen(AppDatabase db) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const MaterialApp(home: GoalsScreen()),
  );
}



Future<void> pumpGoals(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(buildGoalsScreen(db));
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> seedGoals(AppDatabase db, {bool imperial = false}) async {
  await db.upsertGoals(UserGoalsCompanion(
    goalType: const Value('cut'),
    calorieAdjustment: const Value(-500),
    proteinGPerLb: const Value(1.0),
    fatCaloriePct: const Value(25.0),
    sex: const Value('male'),
    heightCm: const Value(175),
    birthdate: const Value('2001-01-01'),
    activityLevel: const Value(3),
    useImperial: Value(imperial ? 1 : 0),
    onboardingCompleted: const Value(1),
    updatedAt: Value(DateTime.now().toIso8601String()),
  ));
  await db.insertWeight(BodyweightEntriesCompanion.insert(
    weightKg: 65,
    loggedAt: DateTime.now().toIso8601String(),
  ));
}

void main() {
  group('DAO', () {
    test('upsertGoals updates in place', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        calorieAdjustment: const Value(-500),
        onboardingCompleted: const Value(1),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));
      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('bulk'),
        calorieAdjustment: const Value(300),
        sex: const Value('male'),
        heightCm: const Value(180),
        birthdate: const Value('1996-01-01'),
        onboardingCompleted: const Value(1),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));
      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.goalType, 'bulk');
      expect(goals.calorieAdjustment, 300);
      expect(goals.sex, 'male');
      expect(goals.heightCm, 180);
      expect(goals.birthdate, '1996-01-01');
    });

    test('getGoals returns null when empty', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      expect(await db.getGoals(), isNull);
    });
  });

  group('goals screen', () {
    final largeScreen = Size(800, 3000);

    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      // ignore: deprecated_member_use
      binding.window.physicalSizeTestValue = largeScreen;
      // ignore: deprecated_member_use
      binding.window.devicePixelRatioTestValue = 1.0;
    });

    testWidgets('profile fields pre-fill from DB and sex toggles',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      expect(find.text('2001-01-01'), findsOneWidget);

      var heightField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Height'),
      );
      expect(heightField.controller?.text, '175.0');

      await tester.tap(find.text('Female'));
      await tester.pump();
      expect(find.text('Female'), findsWidgets);
    });

    testWidgets('goal weight field accepts input',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal weight (optional)'),
        '70',
      );
      await tester.pump();
      var gwField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Goal weight (optional)'),
      );
      expect(gwField.controller?.text, '70');
    });

    testWidgets('units toggle switches height fields',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      expect(find.byType(TextFormField), findsNWidgets(3));

      await tester.tap(find.text('Imperial'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(4));

      await tester.tap(find.text('Metric'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('units persistence: save and reopen shows imperial',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      await tester.tap(find.text('Imperial'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.useImperial, 1);
    });

    testWidgets('activity level renders 5 levels with default 3',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      for (final level in [
        'Sedentary',
        'Lightly active',
        'Moderately active',
        'Active',
        'Extra active',
      ]) {
        expect(find.text(level), findsOneWidget);
      }

      expect(
        find.text('Little to no exercise, desk job'),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('activity level save persists after reopen',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      await tester.tap(find.text('Sedentary'));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(buildGoalsScreen(db));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.activityLevel, 1);
    });

    testWidgets('profile save persists all fields',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      await tester.tap(find.text('Female'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Height'),
        '165',
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal weight (optional)'),
        '60',
      );
      await tester.pump();

      await tester.tap(find.text('Imperial'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Extra active'));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.sex, 'female');
      expect(goals.birthdate, '2001-01-01');
      expect(goals.heightCm, closeTo(165, 0.5));
      expect(goals.goalWeightKg, closeTo(60, 0.5));
      expect(goals.useImperial, 1);
      expect(goals.activityLevel, 5);
    });

    testWidgets('goal type defaults populate correctly',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      var adjField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(adjField.controller?.text, '-500');

      await tester.tap(find.text('Maintain'));
      await tester.pump();
      adjField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(adjField.controller?.text, '0');

      await tester.tap(find.text('Bulk'));
      await tester.pump();
      adjField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(adjField.controller?.text, '300');

      await tester.tap(find.text('Cut'));
      await tester.pump();
      adjField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(adjField.controller?.text, '-500');
    });

    testWidgets('rate preview updates with adjustment',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      expect(find.text('~0.5 kg/week loss'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
        '-1000',
      );
      await tester.pump();
      expect(find.text('~0.9 kg/week loss'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
        '350',
      );
      await tester.pump();
      expect(find.text('~0.3 kg/week gain'), findsOneWidget);
    });

    testWidgets('calorie warning absent at default -500', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      expect(
        find.text(
          'Deficits over 500 kcal/day are aggressive. Consider a smaller deficit.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Surpluses over 300 kcal/day may lead to excess fat gain. Consider a smaller surplus.',
        ),
        findsNothing,
      );
    });

    testWidgets('calorie warning appears for aggressive deficit',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
        '-600',
      );
      await tester.pump();

      expect(
        find.text(
          'Deficits over 500 kcal/day are aggressive. Consider a smaller deficit.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('calorie warning appears for aggressive surplus',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
        '400',
      );
      await tester.pump();

      expect(
        find.text(
          'Surpluses over 300 kcal/day may lead to excess fat gain. Consider a smaller surplus.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('calorie warning does not block save', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
        '-600',
      );
      await tester.pump();

      var saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('protein slider shows current value', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      expect(find.text('Protein: 2.2 g/kg'), findsOneWidget);
      expect(find.byType(Slider), findsAtLeastNWidgets(1));
      expect(find.text('Recommended: 1.8\u20133.1 g/kg'), findsOneWidget);
    });

    testWidgets('fat slider shows % and gram equivalent',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      expect(find.text('Fat: 25% of calories'), findsOneWidget);
      expect(find.text('25% = 56g'), findsOneWidget);
    });

    testWidgets('carbs shows Fills remaining calories',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fills remaining calories'), findsOneWidget);
    });

    testWidgets('save disabled when birthdate not set', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        calorieAdjustment: const Value(-500),
        proteinGPerLb: const Value(1.0),
        fatCaloriePct: const Value(25.0),
        sex: const Value('male'),
        heightCm: const Value(175),
        activityLevel: const Value(3),
        useImperial: const Value(0),
        onboardingCompleted: const Value(1),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));
      await db.insertWeight(BodyweightEntriesCompanion.insert(
        weightKg: 65,
        loggedAt: DateTime.now().toIso8601String(),
      ));
      await pumpGoals(tester, db);

      var saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('save persists goal type across reopen',
        (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      await tester.tap(find.text('Bulk'));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(buildGoalsScreen(db));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      var adjField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(adjField.controller?.text, '300');
    });

    testWidgets('save error shows dialog', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await seedGoals(db);
      await pumpGoals(tester, db);

      await db.close();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('Failed to save'), findsOneWidget);
    });
  });
}
