import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bioloop/features/dashboard/widgets/calories_sparkline.dart';
import 'package:bioloop/providers/shared_dashboard_range_provider.dart';

void main() {
  final defaultRange = DashboardRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
    maxDays: 30.0,
    xInterval: 7,
  );

  testWidgets('empty state shows prompt when no entries', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CaloriesSparkline(entries: [], range: defaultRange),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Log your first food'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('single point renders correctly', (tester) async {
    final entries = [
      (date: '2026-05-16', calories: 2000.0),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CaloriesSparkline(entries: entries, range: defaultRange),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('multiple points renders line chart', (tester) async {
    final entries = [
      (date: '2026-05-01', calories: 2000.0),
      (date: '2026-05-02', calories: 2200.0),
      (date: '2026-05-03', calories: 1800.0),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CaloriesSparkline(entries: entries, range: defaultRange),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('handles very large calorie values', (tester) async {
    final entries = [
      (date: '2026-05-01', calories: 5000.0),
      (date: '2026-05-02', calories: 6000.0),
      (date: '2026-05-03', calories: 4500.0),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CaloriesSparkline(entries: entries, range: defaultRange),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.textContaining('cal'), findsNothing);
  });

  testWidgets('handles zero-calorie days', (tester) async {
    final entries = [
      (date: '2026-05-01', calories: 0.0),
      (date: '2026-05-02', calories: 2000.0),
      (date: '2026-05-03', calories: 1500.0),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CaloriesSparkline(entries: entries, range: defaultRange),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('filters entries before range start', (tester) async {
    final now = DateTime.now();
    final thirtyFiveDaysAgo = now.subtract(const Duration(days: 35));
    final tenDaysAgo = now.subtract(const Duration(days: 10));
    
    final range = DashboardRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
      maxDays: 30.0,
      xInterval: 7,
    );

    final entries = [
      (date: thirtyFiveDaysAgo.toString().substring(0, 10), calories: 3000.0),
      (date: tenDaysAgo.toString().substring(0, 10), calories: 2000.0),
      (date: now.toString().substring(0, 10), calories: 2200.0),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CaloriesSparkline(entries: entries, range: range),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });
}
