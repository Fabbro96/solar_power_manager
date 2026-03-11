import 'package:flutter_test/flutter_test.dart';
import 'package:solar_power_manager/models/energy_data.dart';
import 'package:solar_power_manager/models/power_sample.dart';

void main() {
  group('EnergyData', () {
    test('supports value initialization', () {
      const data = EnergyData(
        todaysEnergy: '10.5 kWh',
        powerNow: '1500 W',
        lastUpdate: '10/03/2026 12:00:00',
        latestPowerValue: 1500.0,
      );

      expect(data.todaysEnergy, '10.5 kWh');
      expect(data.powerNow, '1500 W');
      expect(data.lastUpdate, '10/03/2026 12:00:00');
      expect(data.latestPowerValue, 1500.0);
    });

    test('provides loading constant with default values', () {
      const data = EnergyData.loading;
      expect(data.todaysEnergy, 'Loading...');
      expect(data.powerNow, 'Loading...');
      expect(data.lastUpdate, '-');
      expect(data.latestPowerValue, isNull);
    });
  });

  group('MonitorState', () {
    test('initializes with default values', () {
      const state = MonitorState();

      expect(state.energyData.powerNow, 'Loading...');
      expect(state.inverterStatus, ConnectionStatus.checking);
      expect(state.internetStatus, ConnectionStatus.checking);
      expect(state.errorDetail, isNull);
      expect(state.powerHistory, isEmpty);
    });

    test('copyWith updates specified fields', () {
      const state = MonitorState();

      final energyData = const EnergyData(
        todaysEnergy: '5 kWh',
        powerNow: '500 W',
        lastUpdate: 'Test Time',
      );
      final newHistory = [
        PowerSample(timestamp: DateTime(2026, 3, 11, 9, 47), watts: 500),
      ];

      final newState = state.copyWith(
        energyData: energyData,
        inverterStatus: ConnectionStatus.connected,
        internetStatus: ConnectionStatus.error,
        errorDetail: 'Network Timeout',
        powerHistory: newHistory,
      );

      expect(newState.energyData.powerNow, '500 W');
      expect(newState.inverterStatus, ConnectionStatus.connected);
      expect(newState.internetStatus, ConnectionStatus.error);
      expect(newState.errorDetail, 'Network Timeout');
      expect(newState.powerHistory, newHistory);
    });

    test('copyWith leaves unspecified fields unchanged', () {
      const state = MonitorState(
        inverterStatus: ConnectionStatus.connected,
        errorDetail: 'Initial Error',
      );

      final newState = state.copyWith(
        internetStatus: ConnectionStatus.connected,
      );

      expect(newState.inverterStatus, ConnectionStatus.connected);
      expect(newState.errorDetail, 'Initial Error');
      expect(newState.internetStatus, ConnectionStatus.connected);
    });
  });
}
