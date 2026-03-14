// Basic smoke test for the Solar Power Manager app.


import 'package:flutter_test/flutter_test.dart';

import 'package:solar_power_manager/controllers/energy_controller.dart';
import 'package:solar_power_manager/main.dart';
import 'package:solar_power_manager/services/energy_service.dart';

class _NoopEnergyController extends EnergyController {
  _NoopEnergyController({required super.service});

  @override
  void start() {}

  @override
  void stop() {}
}

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    final service = EnergyService(
      config: const EnergyServiceConfig(url: '', username: '', password: ''),
    );
    final controller = _NoopEnergyController(service: service);

    await tester.pumpWidget(SolarPowerApp(controller: controller));
  });
}
