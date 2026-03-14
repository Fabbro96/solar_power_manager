import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'controllers/energy_controller.dart';
import 'screens/energy_monitor_screen.dart';
import 'services/energy_service.dart';
import 'services/power_history_service.dart';
import 'services/settings_service.dart';
import 'services/app_log_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  late final SettingsService settings;
  late final PowerHistoryService historyService;
  try {
    settings = await SettingsService.create();
    historyService = await PowerHistoryService.create();
  } catch (e) {
    runApp(_StartupErrorApp(message: e.toString()));
    return;
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final appLogs = AppLogService();
  await appLogs.init();

  final energyService = EnergyService(
    config: EnergyServiceConfig(
      url: settings.inverterUrl,
      username: settings.username,
      password: settings.password,
    ),
    logService: appLogs,
  );

  final controller = EnergyController(
    service: energyService,
    historyService: historyService,
    logService: appLogs,
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

  // Schedule periodic version checks
  unawaited(controller.scheduleVersionCheck());
}

/// Shown when startup services fail to initialise (e.g. corrupted asset file).
class _StartupErrorApp extends StatelessWidget {
  final String message;
  const _StartupErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Startup error:\n$message',
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
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
