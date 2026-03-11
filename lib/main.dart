import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'controllers/energy_controller.dart';
import 'screens/energy_monitor_screen.dart';
import 'services/energy_service.dart';
import 'services/power_history_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await SettingsService.create();
  final historyService = await PowerHistoryService.create();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final energyService = EnergyService(
    config: EnergyServiceConfig(
      url: settings.inverterUrl,
      username: settings.username,
      password: settings.password,
    ),
  );

  final controller = EnergyController(
    service: energyService,
    historyService: historyService,
    config: const AppConfig(
      fetchInterval: Duration(seconds: 90),
      minFetchInterval: Duration(seconds: 45),
      maxFetchInterval: Duration(minutes: 6),
      stableDeltaThresholdWatts: 18,
      stableSamplesForBackoff: 3,
      maxChartPoints: 60,
    ),
  );

  runApp(SolarPowerApp(controller: controller, settings: settings));
}

class SolarPowerApp extends StatelessWidget {
  final EnergyController controller;
  final SettingsService? settings;

  const SolarPowerApp({
    super.key,
    required this.controller,
    this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Power Manager',
      theme: buildAppTheme(),
      home: EnergyMonitorScreen(
        controller: controller,
        onIpSaved: settings?.setInverterIp,
      ),
    );
  }
}
