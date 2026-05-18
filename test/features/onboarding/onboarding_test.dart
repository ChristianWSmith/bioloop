import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/onboarding/onboarding_screen.dart';
import 'package:bioloop/providers/database_provider.dart';

ProviderScope buildOnboardingScreen(AppDatabase db) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      home: OnboardingScreen(onComplete: () {}),
    ),
  );
}

Future<void> pumpOnboarding(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(buildOnboardingScreen(db));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> fillOnboardingForm(WidgetTester tester, {
  String sex = 'Male',
  String birthdate = '2001-01-01',
  bool imperial = true,
  String heightFt = '5',
  String heightIn = '10',
  String heightCm = '178',
  String weight = '180',
}) async {
  // Tap birthdate field to set it
  await tester.tap(find.text('Select your birthdate'));
  await tester.pump();
  await tester.tap(find.text('OK'));
  await tester.pump();

  if (imperial) {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Height (ft)'),
      heightFt,
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Height (in)'),
      heightIn,
    );
    await tester.pump();
  } else {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Height'),
      heightCm,
    );
    await tester.pump();
  }

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Weight'),
    weight,
  );
  await tester.pump();
}

void main() {
  final largeScreen = Size(800, 3000);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    // ignore: deprecated_member_use
    binding.window.physicalSizeTestValue = largeScreen;
    // ignore: deprecated_member_use
    binding.window.devicePixelRatioTestValue = 1.0;
  });

  group('protein basis toggle', () {
    testWidgets('renders with bodyweight selected by default', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await pumpOnboarding(tester, db);

      expect(find.text('Per lb bodyweight'), findsOneWidget);
      expect(find.text('Per cm height'), findsOneWidget);

      // Bodyweight segment should be selected (has check icon)
      expect(find.text('Protein: 1.0 g/lb'), findsOneWidget);
      expect(find.text('Recommended: 0.8–1.4 g/lb'), findsOneWidget);
    });

    testWidgets('tap height basis → slider label shows g/cm', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await pumpOnboarding(tester, db);

      await tester.tap(find.text('Per cm height'));
      await tester.pump();

      expect(find.text('Recommended: 0.8–1.4 g/cm'), findsOneWidget);
    });

    testWidgets('tap bodyweight basis → slider label shows g/lb (imperial)', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await pumpOnboarding(tester, db);

      // Already on bodyweight, verify imperial unit
      expect(find.text('Protein: 1.0 g/lb'), findsOneWidget);
    });

    testWidgets('metric user sees g/kg when bodyweight basis selected', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await pumpOnboarding(tester, db);

      // Switch to metric
      await tester.tap(find.text('Metric'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Protein: 2.2 g/kg'), findsOneWidget);
      expect(find.text('Recommended: 1.8–3.1 g/kg'), findsOneWidget);
    });

    testWidgets('save persists proteinBasis == height to DB', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await pumpOnboarding(tester, db);

      await fillOnboardingForm(tester);

      // Switch to height basis
      await tester.tap(find.text('Per cm height'));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.proteinBasis, 'height');
    });

    testWidgets('save persists proteinBasis == bodyweight to DB', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());
      await pumpOnboarding(tester, db);

      await fillOnboardingForm(tester);

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.proteinBasis, 'bodyweight');
    });
  });
}
