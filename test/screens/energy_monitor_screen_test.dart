import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:solar_power_manager/config/app_config.dart';
import 'package:solar_power_manager/controllers/energy_controller.dart';
import 'package:solar_power_manager/screens/energy_monitor_screen.dart';
import 'package:solar_power_manager/services/energy_service.dart';
import 'package:solar_power_manager/widgets/energy_info_card.dart';

void main() {
  testWidgets('EnergyMonitorScreen initializes and shows loading state',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async => throw Exception('Mock'));

    final controller = EnergyController(
      service: EnergyService(
        config: const EnergyServiceConfig(url: '', username: '', password: ''),
        client: mockClient,
      ),
      config: const AppConfig(
          fetchInterval: Duration(hours: 1)), // Avoid fast timers in test
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EnergyMonitorScreen(controller: controller),
      ),
    );

    // App bar should show the IP settings icon (no title text)
    expect(find.byIcon(Icons.settings_ethernet), findsOneWidget);

    // Cards should say "Loading..." initially since Future isn't done yet (or it threw)
    final cards = find.byType(EnergyInfoCard);
    expect(cards, findsNWidgets(2)); // Current Power and Today

    expect(find.text('Loading...'), findsWidgets);

    controller.stop();
  });
}
