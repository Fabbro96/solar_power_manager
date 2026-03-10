import 'package:fl_chart/fl_chart.dart';

class EnergyData {
  final String todaysEnergy;
  final String powerNow;
  final String lastUpdate;
  final double? latestPowerValue;

  const EnergyData({
    required this.todaysEnergy,
    required this.powerNow,
    required this.lastUpdate,
    this.latestPowerValue,
  });

  static const loading = EnergyData(
    todaysEnergy: 'Loading...',
    powerNow: 'Loading...',
    lastUpdate: '-',
  );
}

enum ConnectionStatus { connected, error, checking }

class MonitorState {
  final EnergyData energyData;
  final ConnectionStatus inverterStatus;
  final ConnectionStatus internetStatus;
  final String? errorDetail;
  final List<FlSpot> powerHistory;

  const MonitorState({
    this.energyData = const EnergyData(
      todaysEnergy: 'Loading...',
      powerNow: 'Loading...',
      lastUpdate: '-',
    ),
    this.inverterStatus = ConnectionStatus.checking,
    this.internetStatus = ConnectionStatus.checking,
    this.errorDetail,
    this.powerHistory = const [],
  });

  MonitorState copyWith({
    EnergyData? energyData,
    ConnectionStatus? inverterStatus,
    ConnectionStatus? internetStatus,
    String? errorDetail,
    List<FlSpot>? powerHistory,
  }) {
    return MonitorState(
      energyData: energyData ?? this.energyData,
      inverterStatus: inverterStatus ?? this.inverterStatus,
      internetStatus: internetStatus ?? this.internetStatus,
      errorDetail: errorDetail ?? this.errorDetail,
      powerHistory: powerHistory ?? this.powerHistory,
    );
  }
}
