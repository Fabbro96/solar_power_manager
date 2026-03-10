// Basic smoke test for the Solar Power Manager app.

import 'package:flutter_test/flutter_test.dart';

import 'package:solar_power_manager/config/app_config.dart';
import 'package:solar_power_manager/controllers/energy_controller.dart';
import 'package:solar_power_manager/main.dart';
import 'package:solar_power_manager/services/energy_service.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    const config = AppConfig(
      inverterUrl: 'mock',
      username: 'mock',
      password: 'mock',
    );
    final service = EnergyService(
      config: const EnergyServiceConfig(url: '', username: '', password: ''),
    );
    final controller = EnergyController(service: service, config: config);

    await tester.pumpWidget(SolarPowerApp(controller: controller));
    expect(find.textContaining('Solar Monitor'), findsOneWidget);
  });
}
