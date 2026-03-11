import 'power_sample.dart';

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
  final List<PowerSample> powerHistory;
  final ChartRange chartRange;
  final bool chartLoading;

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
    this.chartRange = ChartRange.last24Hours,
    this.chartLoading = false,
  });

  MonitorState copyWith({
    EnergyData? energyData,
    ConnectionStatus? inverterStatus,
    ConnectionStatus? internetStatus,
    String? errorDetail,
    List<PowerSample>? powerHistory,
    ChartRange? chartRange,
    bool? chartLoading,
  }) {
    return MonitorState(
      energyData: energyData ?? this.energyData,
      inverterStatus: inverterStatus ?? this.inverterStatus,
      internetStatus: internetStatus ?? this.internetStatus,
      errorDetail: errorDetail ?? this.errorDetail,
      powerHistory: powerHistory ?? this.powerHistory,
      chartRange: chartRange ?? this.chartRange,
      chartLoading: chartLoading ?? this.chartLoading,
    );
  }

  double? get minPower {
    if (powerHistory.isEmpty) return null;
    return powerHistory.map((s) => s.watts).reduce((a, b) => a < b ? a : b);
  }

  double? get maxPower {
    if (powerHistory.isEmpty) return null;
    return powerHistory.map((s) => s.watts).reduce((a, b) => a > b ? a : b);
  }

  double? get avgPower {
    if (powerHistory.isEmpty) return null;
    final total = powerHistory.fold<double>(0, (sum, s) => sum + s.watts);
    return total / powerHistory.length;
  }
}
