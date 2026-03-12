import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_power_manager/config/app_config.dart';
import 'package:solar_power_manager/controllers/energy_controller.dart';
import 'package:solar_power_manager/models/energy_data.dart';
import 'package:solar_power_manager/models/power_sample.dart';
import 'package:solar_power_manager/services/energy_service.dart';

void main() {
  EnergyController buildController() {
    final client = MockClient((request) async {
      if (request.url.host.contains('google.com')) {
        return http.Response('OK', 200);
      }

      return http.Response('''
        <html><body><table>
          <tr><td>Today's Energy:</td><td>12.1 kWh</td></tr>
          <tr><td>Power Now:</td><td>1800 W</td></tr>
        </table></body></html>
      ''', 200);
    });

    final service = EnergyService(
      config: const EnergyServiceConfig(
        url: 'http://192.168.1.16/monitor.htm',
        username: 'admin',
        password: 'admin',
      ),
      client: client,
    );

    return EnergyController(
      service: service,
      config: const AppConfig(fetchInterval: Duration(hours: 1)),
    );
  }

  group('EnergyController', () {
    test('setChartRange updates selected range and completes loading',
        () async {
      final controller = buildController();

      await controller.setChartRange(ChartRange.last7Days);

      expect(controller.state.chartRange, ChartRange.last7Days);
      expect(controller.state.chartLoading, isFalse);
      expect(controller.state.powerHistory, isEmpty);

      controller.dispose();
    });

    test('updateInverterIp preserves current chart range', () async {
      final controller = buildController();

      await controller.setChartRange(ChartRange.last30Days);
      await controller.updateInverterIp('192.168.1.50');

      expect(controller.currentInverterIp, '192.168.1.50');
      expect(controller.state.chartRange, ChartRange.last30Days);

      controller.dispose();
    });

    test('probeInverterIp succeeds on reachable inverter', () async {
      final controller = buildController();

      final result = await controller.probeInverterIp('192.168.1.50');

      expect(result.success, isTrue);
      expect(result.message, contains('Connessione riuscita'));

      controller.dispose();
    });

    test('updateInverterIp rejects invalid IPv4 input', () async {
      final controller = buildController();

      expect(
        () => controller.updateInverterIp('192.168.1.999'),
        throwsA(isA<EnergyServiceException>()),
      );

      controller.dispose();
    });

    test('start can be called twice without creating lifecycle errors', () {
      final controller = buildController();

      expect(() {
        controller.start();
        controller.start();
      }, returnsNormally);

      controller.stop();
      controller.dispose();
    });

    test('updateState after dispose is safely ignored', () {
      final controller = buildController();
      controller.dispose();

      expect(
        () => controller.updateState(
          const MonitorState(chartRange: ChartRange.last90Days),
        ),
        returnsNormally,
      );
    });
  });
}
