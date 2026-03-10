import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_power_manager/widgets/energy_info_card.dart';

void main() {
  testWidgets('EnergyInfoCard displays label and value correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EnergyInfoCard(
            label: 'Test Label',
            value: '999 W',
          ),
        ),
      ),
    );

    expect(find.text('Test Label'), findsOneWidget);
    expect(find.text('999 W'), findsOneWidget);
  });
}
