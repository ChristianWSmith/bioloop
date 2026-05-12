import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:bioloop/core/algorithms/maintenance_calculator.dart';
import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/dashboard/dashboard_screen.dart';
import 'package:bioloop/features/dashboard/widgets/bodyweight_sparkline.dart';
import 'package:bioloop/features/dashboard/widgets/macro_ring.dart';
import 'package:bioloop/features/dashboard/widgets/maintenance_card.dart';
import 'package:bioloop/providers/bodyweight_provider.dart';
import 'package:bioloop/providers/food_log_provider.dart';
import 'package:bioloop/providers/goals_provider.dart';
import 'package:bioloop/providers/macro_targets_provider.dart';
import 'package:bioloop/providers/maintenance_provider.dart';
import 'package:bioloop/providers/database_provider.dart';

Widget buildDashboard(
  List<FoodEntry> entries,
  MacroTargets targets, {
  List<BodyweightEntry> weights = const [],
  UserGoal? goals,
  MaintenanceResult? maintenance,
  AppDatabase? db,
}) {
  final database = db ?? AppDatabase.createInMemory();
  return ProviderScope(
    overrides: [
      todaysFoodProvider.overrideWith((ref) async => entries),
      macroTargetsProvider.overrideWith((ref) async => targets),
      bodyweightProvider.overrideWith((ref) async => weights),
      userGoalsProvider.overrideWith((ref) async => goals),
      maintenanceProvider.overrideWith((ref) async => maintenance),
      databaseProvider.overrideWithValue(database),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: DashboardScreen(),
      ),
    ),
  );
}

void main() {
  group('MacroRing', () {
    testWidgets('renders with consumed and target values', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox(
            width: 220,
            child: MacroRing(
              consumed: 500,
              target: 2000,
              label: 'Calories',
              unit: 'kcal',
              color: Colors.blue,
              large: true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('500'), findsOneWidget);
      expect(find.textContaining('2,000'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
    });

    testWidgets('shows remaining for large ring', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox(
            width: 220,
            child: MacroRing(
              consumed: 500,
              target: 2000,
              label: 'Calories',
              unit: 'kcal',
              color: Colors.blue,
              large: true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('remaining'), findsOneWidget);
    });

    testWidgets('partial fill shows correct ratio', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox(
            width: 120,
            child: MacroRing(
              consumed: 50,
              target: 176,
              label: 'Protein',
              unit: 'g',
              color: Colors.blue,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('50'), findsOneWidget);
      expect(find.textContaining('176'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
    });

    testWidgets('over-consumption turns ring red and shows over text',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox(
            width: 220,
            child: MacroRing(
              consumed: 2200,
              target: 2000,
              label: 'Calories',
              unit: 'kcal',
              color: Colors.blue,
              large: true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('over'), findsOneWidget);
    });

    testWidgets('ring animates from 0 on first load', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: MacroRing(
              consumed: 500,
              target: 2000,
              label: 'Calories',
              unit: 'kcal',
              color: Colors.blue,
              large: true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('500'), findsOneWidget);
    });
  });

  group('DashboardScreen', () {
    MacroTargets makeTargets({
      double calorieAdjustment = 0,
    }) {
      return MacroTargets.compute(
        goals: UserGoal(
          id: 1,
          goalType: 'cut',
          calorieAdjustment: calorieAdjustment,
          proteinGPerLb: 1.0,
          fatCaloriePct: 25.0,
          sex: 'male',
          heightCm: 178,
          age: 30,
          goalWeightKg: null,
          useImperial: 0,
          activityLevel: 3,
          onboardingCompleted: 1,
          updatedAt: '2026-01-01',
        ),
        weightKg: 80,
        regressionMaintenance: 2500,
      );
    }

    MacroTargets makeTargets({
      double calorieAdjustment = 0,
      double? goalWeightKg,
    }) {
      return MacroTargets.compute(
        goals: UserGoal(
          id: 1,
          goalType: 'cut',
          calorieAdjustment: calorieAdjustment,
          proteinGPerLb: 1.0,
          fatCaloriePct: 25.0,
          sex: 'male',
          heightCm: 178,
          age: 30,
          goalWeightKg: goalWeightKg,
          useImperial: 0,
          activityLevel: 3,
          onboardingCompleted: 1,
          updatedAt: '2026-01-01',
        ),
        weightKg: 80,
        regressionMaintenance: 2500,
      );
    }

    testWidgets('empty day shows consumed at 0', (tester) async {
      final targets = makeTargets();
      await tester.pumpWidget(buildDashboard([], targets));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsNWidgets(4));
    });

    testWidgets('macro rings have correct colors', (tester) async {
      final targets = makeTargets();
      final entry = FoodEntry(
        id: 1,
        name: 'Test',
        calories: 500,
        proteinGrams: 30,
        carbsGrams: 40,
        fatGrams: 20,
        servings: 1,
        servingLabel: 'serving',
        barcode: null,
        foodId: null,
        recipeId: null,
        mealType: 'snack',
        loggedAt: DateTime.now().toIso8601String(),
      );

      await tester.pumpWidget(buildDashboard([entry], targets));
      await tester.pumpAndSettle();

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
    });

    testWidgets('goal weight card shows delta', (tester) async {
      final targets = makeTargets(goalWeightKg: 75);
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final weights = [
        BodyweightEntry(id: 1, weightKg: 82, loggedAt: dateStr),
      ];
      final goals = UserGoal(
        id: 1,
        goalType: 'cut',
        calorieAdjustment: -500,
        proteinGPerLb: 1.0,
        fatCaloriePct: 25.0,
        sex: 'male',
        heightCm: 178,
        age: 30,
        goalWeightKg: 75,
        useImperial: 0,
        activityLevel: 3,
        onboardingCompleted: 1,
        updatedAt: '2026-01-01',
      );

      await tester.pumpWidget(buildDashboard([], targets,
          weights: weights, goals: goals));
      await tester.pumpAndSettle();

      expect(find.textContaining('82 kg'), findsOneWidget);
      expect(find.textContaining('75 kg'), findsOneWidget);
      expect(find.textContaining('7 kg to go'), findsOneWidget);
    });

    testWidgets('goal weight card hidden when goals null', (tester) async {
      final targets = makeTargets(goalWeightKg: 75);
      await tester.pumpWidget(buildDashboard([], targets));
      await tester.pumpAndSettle();

      expect(find.textContaining('kg to go'), findsNothing);
    });

    testWidgets('goal weight card shows imperial', (tester) async {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final weights = [
        BodyweightEntry(id: 1, weightKg: 82, loggedAt: dateStr),
      ];
      final goals = UserGoal(
        id: 1,
        goalType: 'cut',
        calorieAdjustment: -500,
        proteinGPerLb: 1.0,
        fatCaloriePct: 25.0,
        sex: 'male',
        heightCm: 178,
        age: 30,
        goalWeightKg: 75,
        useImperial: 1,
        activityLevel: 3,
        onboardingCompleted: 1,
        updatedAt: '2026-01-01',
      );

      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: 82,
        regressionMaintenance: 2500,
      );

      await tester.pumpWidget(buildDashboard([], targets,
          weights: weights, goals: goals));
      await tester.pumpAndSettle();

      expect(find.textContaining('181 lb'), findsOneWidget);
      expect(find.textContaining('165 lb'), findsOneWidget);
    });

    testWidgets('rate card shows loss with deficit', (tester) async {
      final goals = UserGoal(
        id: 1,
        goalType: 'cut',
        calorieAdjustment: -500,
        proteinGPerLb: 1.0,
        fatCaloriePct: 25.0,
        sex: 'male',
        heightCm: 178,
        age: 30,
        goalWeightKg: null,
        useImperial: 0,
        activityLevel: 3,
        onboardingCompleted: 1,
        updatedAt: '2026-01-01',
      );
      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: 80,
        regressionMaintenance: 2500,
      );

      await tester.pumpWidget(buildDashboard([], targets, goals: goals));
      await tester.pumpAndSettle();

      expect(find.textContaining('loss'), findsOneWidget);
    });

    testWidgets('rate card shows gain with surplus', (tester) async {
      final goals = UserGoal(
        id: 1,
        goalType: 'bulk',
        calorieAdjustment: 300,
        proteinGPerLb: 1.0,
        fatCaloriePct: 25.0,
        sex: 'male',
        heightCm: 178,
        age: 30,
        goalWeightKg: null,
        useImperial: 0,
        activityLevel: 3,
        onboardingCompleted: 1,
        updatedAt: '2026-01-01',
      );
      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: 80,
        regressionMaintenance: 2500,
      );

      await tester.pumpWidget(buildDashboard([], targets, goals: goals));
      await tester.pumpAndSettle();

      expect(find.textContaining('gain'), findsOneWidget);
    });

    testWidgets('rate card shows maintenance', (tester) async {
      final goals = UserGoal(
        id: 1,
        goalType: 'maintain',
        calorieAdjustment: 0,
        proteinGPerLb: 1.0,
        fatCaloriePct: 25.0,
        sex: 'male',
        heightCm: 178,
        age: 30,
        goalWeightKg: null,
        useImperial: 0,
        activityLevel: 3,
        onboardingCompleted: 1,
        updatedAt: '2026-01-01',
      );
      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: 80,
        regressionMaintenance: 2500,
      );

      await tester.pumpWidget(buildDashboard([], targets, goals: goals));
      await tester.pumpAndSettle();

      expect(find.text('Maintenance'), findsOneWidget);
    });

    testWidgets('rate card hidden when goals null', (tester) async {
      final targets = makeTargets();
      await tester.pumpWidget(buildDashboard([], targets));
      await tester.pumpAndSettle();

      expect(find.text('Maintenance'), findsNothing);
      expect(find.textContaining('loss'), findsNothing);
      expect(find.textContaining('gain'), findsNothing);
    });

    testWidgets('onboarding shown when no food, weight, goals',
        (tester) async {
      final targets = makeTargets();
      await tester.pumpWidget(buildDashboard([], targets));
      await tester.pumpAndSettle();

      expect(find.text('Log your first meal'), findsOneWidget);
    });

    testWidgets('onboarding hidden when food present', (tester) async {
      final targets = makeTargets();
      final entry = FoodEntry(
        id: 1,
        name: 'Test',
        calories: 500,
        proteinGrams: 30,
        carbsGrams: 40,
        fatGrams: 20,
        servings: 1,
        servingLabel: 'serving',
        barcode: null,
        foodId: null,
        recipeId: null,
        mealType: 'snack',
        loggedAt: DateTime.now().toIso8601String(),
      );

      await tester.pumpWidget(buildDashboard([entry], targets));
      await tester.pumpAndSettle();

      expect(find.text('Log your first meal'), findsNothing);
      expect(find.text('Calories'), findsOneWidget);
    });

    testWidgets('all sections render without overflow', (tester) async {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final weights = List.generate(10, (i) {
        final day = now.subtract(Duration(days: i * 2));
        final dStr =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        return BodyweightEntry(id: i + 1, weightKg: 80 + i * 0.2, loggedAt: dStr);
      });
      final goals = UserGoal(
        id: 1,
        goalType: 'cut',
        calorieAdjustment: -500,
        proteinGPerLb: 1.0,
        fatCaloriePct: 25.0,
        sex: 'male',
        heightCm: 178,
        age: 30,
        goalWeightKg: 75,
        useImperial: 0,
        activityLevel: 3,
        onboardingCompleted: 1,
        updatedAt: '2026-01-01',
      );
      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: 80,
        regressionMaintenance: 2500,
      );

      await tester.pumpWidget(buildDashboard([], targets,
          weights: weights, goals: goals));
      await tester.pumpAndSettle();

      expect(find.byType(Scrollable), findsOneWidget);
      expect(find.text('Today,'), findsOneWidget);
      expect(find.textContaining('loss'), findsOneWidget);
      expect(find.textContaining('Maintenance Calories'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    });
  });

  group('todaysFoodProvider', () {
    test('returns only today entries with correct aggregate totals',
        () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      await db.insertEntry(FoodEntriesCompanion(
        name: const Value('Food 1'),
        calories: const Value(500),
        proteinGrams: const Value(30),
        carbsGrams: const Value(40),
        fatGrams: const Value(20),
        servings: const Value(1),
        servingLabel: const Value('serving'),
        mealType: const Value('snack'),
        loggedAt: Value(DateTime(today.year, today.month, today.day, 10)
            .toIso8601String()),
      ));
      await db.insertEntry(FoodEntriesCompanion(
        name: const Value('Food 2'),
        calories: const Value(300),
        proteinGrams: const Value(20),
        carbsGrams: const Value(30),
        fatGrams: const Value(10),
        servings: const Value(1),
        servingLabel: const Value('serving'),
        mealType: const Value('lunch'),
        loggedAt: Value(DateTime(today.year, today.month, today.day, 13)
            .toIso8601String()),
      ));
      await db.insertEntry(FoodEntriesCompanion(
        name: const Value('Food 3'),
        calories: const Value(200),
        proteinGrams: const Value(10),
        carbsGrams: const Value(20),
        fatGrams: const Value(5),
        servings: const Value(1),
        servingLabel: const Value('serving'),
        mealType: const Value('dinner'),
        loggedAt: Value(DateTime(today.year, today.month, today.day, 19)
            .toIso8601String()),
      ));

      await db.insertEntry(FoodEntriesCompanion(
        name: const Value('Yesterday Food'),
        calories: const Value(1000),
        proteinGrams: const Value(50),
        carbsGrams: const Value(100),
        fatGrams: const Value(40),
        servings: const Value(1),
        servingLabel: const Value('serving'),
        mealType: const Value('snack'),
        loggedAt: Value(DateTime(yesterday.year, yesterday.month, yesterday.day)
            .toIso8601String()),
      ));

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(() => container.dispose());

      final entries = await container.read(todaysFoodProvider.future);

      expect(entries.length, 3);

      double sumCal = 0, sumPro = 0, sumCarb = 0, sumFat = 0;
      for (final e in entries) {
        sumCal += e.calories;
        sumPro += e.proteinGrams;
        sumCarb += e.carbsGrams;
        sumFat += e.fatGrams;
      }
      expect(sumCal, closeTo(1000, 1));
      expect(sumPro, closeTo(60, 1));
      expect(sumCarb, closeTo(90, 1));
      expect(sumFat, closeTo(35, 1));
    });
  });

  group('BodyweightSparkline', () {
    UserGoal makeGoal({int useImperial = 0}) {
      return UserGoal(
        id: 1,
        goalType: 'maintain',
        calorieAdjustment: 0,
        proteinGPerLb: 1.0,
        fatCaloriePct: 25.0,
        sex: 'male',
        heightCm: 178,
        age: 30,
        goalWeightKg: null,
        useImperial: useImperial,
        activityLevel: 3,
        onboardingCompleted: 1,
        updatedAt: '2026-01-01',
      );
    }

    Widget buildSparkline(List<BodyweightEntry> entries,
        {int useImperial = 0}) {
      return ProviderScope(
        overrides: [
          userGoalsProvider.overrideWith(
            (ref) async => makeGoal(useImperial: useImperial),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BodyweightSparkline(entries: entries),
          ),
        ),
      );
    }

    BodyweightEntry makeEntry({
      required int id,
      required double weightKg,
      required DateTime date,
    }) {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return BodyweightEntry(id: id, weightKg: weightKg, loggedAt: dateStr);
    }

    List<BodyweightEntry> makeEntries(int count) {
      final now = DateTime.now();
      return List.generate(count, (i) {
        final day = now.subtract(Duration(days: i * 3));
        return makeEntry(
            id: i + 1, weightKg: 80 + (i % 5) * 0.5, date: day);
      });
    }

    testWidgets('empty state shows prompt when no entries', (tester) async {
      await tester.pumpWidget(buildSparkline([]));
      await tester.pumpAndSettle();

      expect(find.text('Log your first weight'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('single point renders as chart dot', (tester) async {
      final entries = [
        makeEntry(id: 1, weightKg: 80, date: DateTime.now()),
      ];
      await tester.pumpWidget(buildSparkline(entries));
      await tester.pumpAndSettle();

      expect(find.text('Log your first weight'), findsNothing);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('multiple points renders line chart', (tester) async {
      final entries = makeEntries(10);
      await tester.pumpWidget(buildSparkline(entries));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Log your first weight'), findsNothing);
    });

    testWidgets('chart handles touch interaction', (tester) async {
      final now = DateTime.now();
      final entries = [
        makeEntry(id: 1, weightKg: 80, date: now.subtract(const Duration(days: 10))),
        makeEntry(id: 2, weightKg: 81, date: now.subtract(const Duration(days: 5))),
        makeEntry(id: 3, weightKg: 82, date: now),
      ];
      await tester.pumpWidget(buildSparkline(entries));
      await tester.pumpAndSettle();

      // Touch-hold triggers fl_chart's built-in tooltip
      await tester.tap(find.byType(LineChart));
      await tester.pumpAndSettle();

      // Chart still renders after touch
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('fits within 200px height', (tester) async {
      final entries = makeEntries(10);
      await tester.pumpWidget(
        SizedBox(
          height: 200,
          child: buildSparkline(entries),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('rebuild with new entries updates chart', (tester) async {
      final entries = makeEntries(3);
      await tester.pumpWidget(buildSparkline(entries));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);

      final moreEntries = makeEntries(10);
      await tester.pumpWidget(buildSparkline(moreEntries));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Log your first weight'), findsNothing);
    });
  });

  group('computeBodyweightTrend', () {
    BodyweightEntry makeEntry({
      required int id,
      required double weightKg,
      required DateTime date,
    }) {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return BodyweightEntry(id: id, weightKg: weightKg, loggedAt: dateStr);
    }

    test('returns null for fewer than 7 entries', () {
      final now = DateTime.now();
      final entries = List.generate(6, (i) {
        final day = now.subtract(Duration(days: i * 3));
        return makeEntry(id: i + 1, weightKg: 80 + i * 0.5, date: day);
      });

      expect(computeBodyweightTrend(entries), isNull);
    });

    test('smoothes a middle spike toward surrounding values', () {
      final now = DateTime.now();
      final entries = List.generate(10, (i) {
        final day = now.subtract(Duration(days: 30 - i * 3));
        final weight = i == 5 ? 100.0 : 80.0;
        return makeEntry(id: i + 1, weightKg: weight, date: day);
      });
      entries.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

      final trend = computeBodyweightTrend(entries);
      expect(trend, isNotNull);
      expect(trend!.length, 10);

      // Spike at index 5 should be pulled down by surrounding 80s
      expect(trend[5], lessThan(95));
    });
  });
}
