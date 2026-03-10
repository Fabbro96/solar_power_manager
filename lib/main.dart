import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'controllers/energy_controller.dart';
import 'screens/energy_monitor_screen.dart';
import 'services/energy_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    // 1. App Configuration (can be loaded from env vars or remote config later)
    const config = AppConfig(
      inverterUrl: 'http://192.168.1.16/monitor.htm',
      username: 'admin',
      password: 'admin',
      fetchInterval: Duration(seconds: 30),
      maxChartPoints: 60,
    );

    // 2. Services Initialization
    final energyService = EnergyService(
      config: EnergyServiceConfig(
        url: config.inverterUrl,
        username: config.username,
        password: config.password,
      ),
    );

    // 3. Controller (State Management) initialization
    final controller = EnergyController(
      service: energyService,
      config: config,
    );

    runApp(SolarPowerApp(controller: controller));
  });
}

class SolarPowerApp extends StatelessWidget {
  final EnergyController controller;

  const SolarPowerApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Power Manager',
      theme: buildAppTheme(),
      home: EnergyMonitorScreen(controller: controller),
    );
  }
}
