import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_power_manager/services/energy_service.dart';

void main() {
  const dummyConfig = EnergyServiceConfig(
    url: 'http://192.168.1.16/monitor.htm',
    username: 'user',
    password: 'pass',
  );

  final dummyHtml = '''
    <html>
      <body>
        <table>
          <tr><td>Today's Energy:</td><td>15.5 kWh</td></tr>
          <tr><td>Power Now:</td><td>2500 W</td></tr>
        </table>
      </body>
    </html>
  ''';

  final variantHtml = '''
    <html>
      <body>
        <table>
          <tr><th>Today</th><td><span>16.2 kWh</span></td></tr>
          <tr><th>Power Now</th><td><strong>2100 W</strong></td></tr>
        </table>
      </body>
    </html>
  ''';

  group('EnergyService', () {
    test('normalizeIpv4 strips leading zeros and validates ranges', () {
      expect(EnergyService.normalizeIpv4('192.168.001.016'), '192.168.1.16');
      expect(EnergyService.normalizeIpv4(' 10.0.0.5 '), '10.0.0.5');
      expect(EnergyService.normalizeIpv4('300.1.1.1'), isNull);
      expect(EnergyService.normalizeIpv4('foo.bar'), isNull);
    });

    test('fetchEnergyData parses HTML correctly on 200 response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), dummyConfig.url);
        // Basic auth contains 'user:pass' -> dXNlcjpwYXNz
        expect(request.headers['Authorization'], 'Basic dXNlcjpwYXNz');
        return http.Response(dummyHtml, 200);
      });

      final service = EnergyService(config: dummyConfig, client: mockClient);
      final data = await service.fetchEnergyData();

      expect(data.todaysEnergy, '15.5 kWh');
      expect(data.powerNow, '2500 W');
      expect(data.latestPowerValue, 2500.0);
      expect(data.lastUpdate, isNotEmpty);
    });

    test('fetchEnergyData throws EnergyServiceException on non-200 response',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final service = EnergyService(config: dummyConfig, client: mockClient);

      expect(
        () => service.fetchEnergyData(),
        throwsA(isA<EnergyServiceException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        )),
      );
    });

    test('fetchEnergyData parses variant monitor table formatting', () async {
      final mockClient = MockClient((request) async {
        return http.Response(variantHtml, 200);
      });

      final service = EnergyService(config: dummyConfig, client: mockClient);
      final data = await service.fetchEnergyData();

      expect(data.todaysEnergy, '16.2 kWh');
      expect(data.powerNow, '2100 W');
      expect(data.latestPowerValue, 2100.0);
    });

    test('checkInternetConnectivity returns true on 200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('OK', 200);
      });

      final service = EnergyService(config: dummyConfig, client: mockClient);
      final isConnected = await service.checkInternetConnectivity();

      expect(isConnected, isTrue);
    });

    test('checkInternetConnectivity returns false on error', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });

      final service = EnergyService(config: dummyConfig, client: mockClient);
      final isConnected = await service.checkInternetConnectivity();

      expect(isConnected, isFalse);
    });

    test('probeInverterConfig validates IPv4 input before request', () async {
      final mockClient = MockClient((request) async {
        fail('HTTP should not be called for invalid IP');
      });

      final service = EnergyService(config: dummyConfig, client: mockClient);

      expect(
        () => service.probeInverterConfig(
            ip: '999.999.1.2', username: 'a', password: 'b'),
        throwsA(isA<EnergyServiceException>()),
      );
    });
  });
}
