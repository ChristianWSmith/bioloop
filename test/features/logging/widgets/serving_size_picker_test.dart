import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/features/logging/widgets/serving_size_picker.dart';

void main() {
  group('ServingSizePicker', () {
    testWidgets('imported food shows filtered dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServingSizePicker(
              quantity: 100,
              unit: 'g',
              source: 'open_food_facts',
              onQuantityChanged: (_) {},
              onUnitChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('g'), findsWidgets);
      expect(find.text('Custom\u2026'), findsWidgets);
      
      expect(find.text('ml'), findsNothing);
      expect(find.text('cups'), findsNothing);
      expect(find.text('oz'), findsNothing);
    });

    testWidgets('null source defaults to all units', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServingSizePicker(
              quantity: 1,
              unit: 'serving',
              source: null,
              onQuantityChanged: (_) {},
              onUnitChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('g'), findsWidgets);
      expect(find.text('ml'), findsWidgets);
      expect(find.text('cups'), findsWidgets);
    });

    testWidgets('imported food with ml unit shows filtered dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServingSizePicker(
              quantity: 240,
              unit: 'ml',
              source: 'open_food_facts',
              onQuantityChanged: (_) {},
              onUnitChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('ml'), findsWidgets);
      expect(find.text('Custom\u2026'), findsWidgets);
      
      expect(find.text('g'), findsNothing);
      expect(find.text('cups'), findsNothing);
    });
  });
}
