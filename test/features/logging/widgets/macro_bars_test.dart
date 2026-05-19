import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bioloop/features/logging/widgets/macro_bars.dart';
import 'package:bioloop/providers/macro_targets_provider.dart';

void main() {
  group('MacroBars', () {

    testWidgets('displays consumed mode by default', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MacroBars(
                targets: MacroTargets(
                  targetCalories: 2000,
                  proteinGrams: 150,
                  fatGrams: 55,
                  carbsGrams: 225,
                  calorieAdjustment: 0,
                  rateLbsPerWeek: 0,
                ),
                consumedCalories: 1500,
                consumedProtein: 100,
                consumedCarbs: 150,
                consumedFat: 40,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1500 / 2000 kcal'), findsOneWidget);
      expect(find.text('40 / 55 g'), findsOneWidget);
      expect(find.text('150 / 225 g'), findsOneWidget);
      expect(find.text('100 / 150 g'), findsOneWidget);
    });

    testWidgets('toggles to remaining mode on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MacroBars(
                targets: MacroTargets(
                  targetCalories: 2000,
                  proteinGrams: 150,
                  fatGrams: 55,
                  carbsGrams: 225,
                  calorieAdjustment: 0,
                  rateLbsPerWeek: 0,
                ),
                consumedCalories: 1500,
                consumedProtein: 100,
                consumedCarbs: 150,
                consumedFat: 40,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(find.text('500 left'), findsOneWidget);
      expect(find.text('15 left'), findsOneWidget);
      expect(find.text('75 left'), findsOneWidget);
      expect(find.text('50 left'), findsOneWidget);
    });

    testWidgets('shows "X left" when under target', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MacroBars(
                targets: MacroTargets(
                  targetCalories: 2000,
                  proteinGrams: 150,
                  fatGrams: 55,
                  carbsGrams: 225,
                  calorieAdjustment: 0,
                  rateLbsPerWeek: 0,
                ),
                consumedCalories: 1500,
                consumedProtein: 100,
                consumedCarbs: 150,
                consumedFat: 40,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(find.text('500 left'), findsOneWidget);
    });

    testWidgets('shows "X over" when over target', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MacroBars(
                targets: MacroTargets(
                  targetCalories: 2000,
                  proteinGrams: 150,
                  fatGrams: 55,
                  carbsGrams: 225,
                  calorieAdjustment: 0,
                  rateLbsPerWeek: 0,
                ),
                consumedCalories: 2500,
                consumedProtein: 200,
                consumedCarbs: 300,
                consumedFat: 80,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(find.text('500 over'), findsOneWidget);
      expect(find.text('50 over'), findsOneWidget);
      expect(find.text('75 over'), findsOneWidget);
      expect(find.text('25 over'), findsOneWidget);
    });

    testWidgets('all macros toggle simultaneously', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MacroBars(
                targets: MacroTargets(
                  targetCalories: 2000,
                  proteinGrams: 150,
                  fatGrams: 55,
                  carbsGrams: 225,
                  calorieAdjustment: 0,
                  rateLbsPerWeek: 0,
                ),
                consumedCalories: 1500,
                consumedProtein: 100,
                consumedCarbs: 150,
                consumedFat: 40,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(find.text('500 left'), findsOneWidget);
      expect(find.text('15 left'), findsOneWidget);
      expect(find.text('75 left'), findsOneWidget);
      expect(find.text('50 left'), findsOneWidget);

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(find.text('1500 / 2000 kcal'), findsOneWidget);
      expect(find.text('40 / 55 g'), findsOneWidget);
      expect(find.text('150 / 225 g'), findsOneWidget);
      expect(find.text('100 / 150 g'), findsOneWidget);
    });

    testWidgets('shows ripple effect on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MacroBars(
                targets: MacroTargets(
                  targetCalories: 2000,
                  proteinGrams: 150,
                  fatGrams: 55,
                  carbsGrams: 225,
                  calorieAdjustment: 0,
                  rateLbsPerWeek: 0,
                ),
                consumedCalories: 1500,
                consumedProtein: 100,
                consumedCarbs: 150,
                consumedFat: 40,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);

      final inkWellFinder = find.byType(InkWell);
      expect(inkWellFinder, findsOneWidget);
    });
  });
}
