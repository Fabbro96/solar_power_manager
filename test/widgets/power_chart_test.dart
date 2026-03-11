import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_power_manager/models/power_sample.dart';
import 'package:solar_power_manager/widgets/power_chart.dart';

void main() {
  testWidgets('PowerChart renders without crashing given empty data',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: 300,
            child: PowerChart(data: []),
          ),
        ),
      ),
    );

    expect(find.byType(PowerChart), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('PowerChart renders without crashing given spots',
      (WidgetTester tester) async {
    final testData = [
      PowerSample(timestamp: DateTime(2026, 3, 11, 9, 45), watts: 500),
      PowerSample(timestamp: DateTime(2026, 3, 11, 9, 46), watts: 600),
      PowerSample(timestamp: DateTime(2026, 3, 11, 9, 47), watts: 700),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: 300,
            child: PowerChart(data: testData),
          ),
        ),
      ),
    );

    expect(find.byType(PowerChart), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
