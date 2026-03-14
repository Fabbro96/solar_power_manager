// Basic smoke test for the Solar Power Manager app.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solar_power_manager/controllers/energy_controller.dart';
import 'package:solar_power_manager/main.dart';
import 'package:solar_power_manager/services/app_log_service.dart';
import 'package:solar_power_manager/services/energy_service.dart';

class _NoopEnergyController extends EnergyController {
  _NoopEnergyController(
      {required EnergyService service, AppLogService? logService})
      : super(service: service, logService: logService);

  @override
  void start() {}

  @override
  void stop() {}

  @override
  void dispose() {}
}

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    print('widget_test: start');

    final tempDir = Directory.systemTemp.createTempSync('widget_test_');
    print('widget_test: created tempDir');

    final logService = AppLogService(flushDelay: Duration.zero);
    await logService.init(basePath: tempDir.path);
    print('widget_test: logService inited');
    logService.info('widget', 'boot');

    final service = EnergyService(
      config: const EnergyServiceConfig(url: '', username: '', password: ''),
    );
    final controller =
        _NoopEnergyController(service: service, logService: logService);

    await tester.pumpWidget(SolarPowerApp(controller: controller));
    print('widget_test: pumped widget');

    print('widget_test: done');
  });
}
