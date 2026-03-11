// Basic smoke test for the Solar Power Manager app.

import 'package:flutter_test/flutter_test.dart';

import 'package:solar_power_manager/controllers/energy_controller.dart';
import 'package:solar_power_manager/main.dart';
import 'package:solar_power_manager/services/energy_service.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    final service = EnergyService(
      config: const EnergyServiceConfig(url: '', username: '', password: ''),
    );
    final controller = EnergyController(service: service);

    await tester.pumpWidget(SolarPowerApp(controller: controller));
    expect(find.textContaining('Solar Monitor'), findsWidgets);

    controller.stop();
  });
}
