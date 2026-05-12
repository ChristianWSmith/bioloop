import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:bioloop/app.dart';
import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/onboarding/onboarding_screen.dart';
import 'package:bioloop/providers/database_provider.dart';

void _noop() {}

ProviderScope buildApp(AppDatabase db) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: App(),
  );
}

Future<void> pumpApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(buildApp(db));
  // Let the async onboarding check complete
  await tester.pump();
  await tester.pump();
}

final _scrollable = find.byType(Scrollable).first;

extension _WidgetTesterX on WidgetTester {
  Future<void> enterTextByLabel(String label, String text) async {
    await scrollUntilVisible(
      find.widgetWithText(TextFormField, label),
      100,
      scrollable: _scrollable,
    );
    await enterText(find.widgetWithText(TextFormField, label), text);
  }
}

Future<void> saveOnboarding(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Save'),
    100,
    scrollable: _scrollable,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  // ── App Shell Tests (DB seeded with onboarding_completed=1) ──

  group('app shell', () {
    Future<AppDatabase> seedDb() async {
      final db = AppDatabase.createInMemory();
      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        onboardingCompleted: const Value(1),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));
      return db;
    }

    testWidgets('renders 5 bottom nav destinations', (tester) async {
      final db = await seedDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('tapping each tab switches body content', (tester) async {
      final db = await seedDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();
      expect(find.text('Log Food'), findsOneWidget);

      await tester.tap(find.text('Bodyweight'));
      await tester.pumpAndSettle();
      expect(find.text('Bodyweight'), findsWidgets);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('History'), findsWidgets);

      await tester.tap(find.text('Goals'));
      await tester.pumpAndSettle();
      expect(find.text('Goals'), findsWidgets);

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets('light theme applies by default', (tester) async {
      final db = await seedDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      final scaffold = tester.element(find.byType(Scaffold));
      final theme = Theme.of(scaffold);
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, true);
    });
  });

  // ── Onboarding Tests ─────────────────────────────────────────

  group('onboarding', () {
    AppDatabase createDb() => AppDatabase.createInMemory();

    testWidgets('appears on fresh install before app shell',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      expect(find.text('Setup'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('skipped on re-launch when onboarding_completed=1',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        onboardingCompleted: const Value(1),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));
      await pumpApp(tester, db);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Setup'), findsNothing);
    });

    testWidgets('full flow: fill all fields, save, verify DB',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      // Sex
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();

      // Age
      await tester.enterTextByLabel('Age', '25');
      await tester.pumpAndSettle();

      // Height
      await tester.enterTextByLabel('Height', '175');
      await tester.pumpAndSettle();

      // Weight
      await tester.enterTextByLabel('Weight', '75');
      await tester.pumpAndSettle();

      // Goal weight
      await tester.enterTextByLabel('Goal weight (optional)', '70');
      await tester.pumpAndSettle();

      // Units — Imperial
      await tester.scrollUntilVisible(find.text('Imperial'), 100, scrollable: _scrollable);
      await tester.tap(find.text('Imperial'));
      await tester.pumpAndSettle();

      // Activity level — Extra active
      await tester.scrollUntilVisible(find.text('Extra active'), 100, scrollable: _scrollable);
      await tester.tap(find.text('Extra active'));
      await tester.pumpAndSettle();

      // Goal type — Bulk
      await tester.scrollUntilVisible(find.text('Bulk'), 100, scrollable: _scrollable);
      await tester.tap(find.text('Bulk'));
      await tester.pumpAndSettle();

      // Calorie adjustment should be 300
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
        100,
        scrollable: _scrollable,
      );
      final adjField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(adjField.controller?.text, '300');

      await saveOnboarding(tester);

      // Shell appears
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verify DB
      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.sex, 'male');
      expect(goals.age, 25);
      expect(goals.heightCm, 175);
      expect(goals.goalWeightKg, 70);
      expect(goals.useImperial, 1);
      expect(goals.activityLevel, 5);
      expect(goals.goalType, 'bulk');
      expect(goals.onboardingCompleted, 1);

      // Bodyweight entry seeded
      final weights = await (db.select(db.bodyweightEntries)).get();
      expect(weights.length, 1);
      expect(weights.first.weightKg, 75);
    });

    testWidgets('skip goal weight: null in DB', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      // Fill required fields only
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Age', '30');
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Height', '165');
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Weight', '60');
      await tester.pumpAndSettle();

      await saveOnboarding(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.goalWeightKg, isNull);
    });

    testWidgets('units default to metric (use_imperial=0)',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      // Metric button is selected by default
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Age', '25');
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Height', '180');
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Weight', '80');
      await tester.pumpAndSettle();

      await saveOnboarding(tester);

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.useImperial, 0);
    });

    testWidgets('activity level defaults to 3', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Age', '25');
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Height', '180');
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Weight', '80');
      await tester.pumpAndSettle();

      await saveOnboarding(tester);

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.activityLevel, 3);
    });

    testWidgets('activity level selection persists (level 5)',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Age', '25');
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Height', '180');
      await tester.pumpAndSettle();
      await tester.enterTextByLabel('Weight', '80');
      await tester.pumpAndSettle();

      // Select Extra active (level 5)
      await tester.scrollUntilVisible(find.text('Extra active'), 100, scrollable: _scrollable);
      await tester.tap(find.text('Extra active'));
      await tester.pumpAndSettle();

      await saveOnboarding(tester);

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.activityLevel, 5);
    });

    testWidgets('validation blocks save with empty required fields',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      await saveOnboarding(tester);

      // Still on onboarding, no shell
      expect(find.text('Setup'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('back press shows confirmation dialog',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProviderScope(
                    overrides: [databaseProvider.overrideWithValue(db)],
                    child: const OnboardingScreen(onComplete: _noop),
                  ),
                ),
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Push onboarding onto navigator
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('Setup'), findsOneWidget);

      // Press back
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Discard progress?'), findsOneWidget);
      expect(find.text('Your progress won\'t be saved.'), findsOneWidget);

      // "Stay" dismisses dialog
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('Discard progress?'), findsNothing);
      expect(find.text('Setup'), findsOneWidget);

      // Press back again
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard progress?'), findsOneWidget);

      // "Leave" pops the route
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Setup'), findsNothing);
    });

    testWidgets('goal type segmented buttons set calorie adjustment defaults',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      // Default should be Cut with -500 — scroll to calorie adjustment field
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
        100,
        scrollable: _scrollable,
      );
      final initialField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(initialField.controller?.text, '-500');

      // Tap Maintain
      await tester.scrollUntilVisible(find.text('Maintain'), 100, scrollable: _scrollable);
      await tester.tap(find.text('Maintain'));
      await tester.pumpAndSettle();
      final maintainField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(maintainField.controller?.text, '0');

      // Tap Bulk
      await tester.tap(find.text('Bulk'));
      await tester.pumpAndSettle();
      final bulkField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(bulkField.controller?.text, '300');

      // Tap Cut again
      await tester.tap(find.text('Cut'));
      await tester.pumpAndSettle();
      final cutField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
      );
      expect(cutField.controller?.text, '-500');
    });

    testWidgets('sliders have correct default values', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      await tester.scrollUntilVisible(find.text('Protein: 1.0 g/lb'), 100, scrollable: _scrollable);
      expect(find.text('Protein: 1.0 g/lb'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Fat: 25% of calories'),
        100,
        scrollable: _scrollable,
      );
      expect(find.text('Fat: 25% of calories'), findsOneWidget);
    });

    testWidgets('keyboard types are correct', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      final ageField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Age'),
          matching: find.byType(TextField),
        ),
      );
      expect(ageField.keyboardType, TextInputType.number);

      final heightField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Height'),
          matching: find.byType(TextField),
        ),
      );
      expect(
        heightField.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );

      final weightField = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Weight'),
          matching: find.byType(TextField),
        ),
      );
      expect(
        weightField.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    });

    testWidgets('rate preview updates when calorie adjustment changes',
        (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      // Scroll to calorie adjustment field
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Calorie adjustment'),
        100,
        scrollable: _scrollable,
      );

      // Default -500 should show loss preview
      expect(find.textContaining('lb/week'), findsOneWidget);

      // Change to 0 — should show "Maintenance"
      await tester.enterTextByLabel('Calorie adjustment', '0');
      await tester.pumpAndSettle();
      expect(find.text('Maintenance'), findsOneWidget);

      // Change to +300 — should show gain preview
      await tester.enterTextByLabel('Calorie adjustment', '300');
      await tester.pumpAndSettle();
      expect(find.textContaining('gain'), findsOneWidget);
    });

    testWidgets('date defaults to today', (tester) async {
      final db = createDb();
      addTearDown(() => db.close());
      await pumpApp(tester, db);

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(find.text(todayStr), findsOneWidget);
    });
  });
}
