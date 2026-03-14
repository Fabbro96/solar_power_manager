// Basic smoke test for the Solar Power Manager app.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solar_power_manager/controllers/energy_controller.dart';
import 'package:solar_power_manager/main.dart';
import 'package:solar_power_manager/services/app_log_service.dart';
import 'package:solar_power_manager/services/energy_service.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    final tempDir = await Directory.systemTemp.createTemp('widget_test_');

    final logService = AppLogService(flushDelay: Duration.zero);
    await logService.init(basePath: tempDir.path);
    logService.info('widget', 'boot');

    final service = EnergyService(
      config: const EnergyServiceConfig(url: '', username: '', password: ''),
    );
    final controller = EnergyController(service: service, logService: logService);

    await tester.pumpWidget(SolarPowerApp(controller: controller));

    // Verify IP button is present and the menu opens.
    expect(find.byIcon(Icons.settings_ethernet), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Show logs'), findsOneWidget);

    // Open the log viewer and ensure it contains the log line.
    await tester.tap(find.text('Show logs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('boot'), findsWidgets);

    logService.dispose();
    await tempDir.delete(recursive: true);
  });
}
