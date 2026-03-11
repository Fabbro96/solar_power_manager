class PowerSample {
  final DateTime timestamp;
  final double watts;

  const PowerSample({
    required this.timestamp,
    required this.watts,
  });
}

enum ChartRange {
  lastHour,
  last24Hours,
  last7Days,
  last30Days,
  last90Days,
}

extension ChartRangeX on ChartRange {
  Duration get duration {
    switch (this) {
      case ChartRange.lastHour:
        return const Duration(hours: 1);
      case ChartRange.last24Hours:
        return const Duration(hours: 24);
      case ChartRange.last7Days:
        return const Duration(days: 7);
      case ChartRange.last30Days:
        return const Duration(days: 30);
      case ChartRange.last90Days:
        return const Duration(days: 90);
    }
  }

  String get label {
    switch (this) {
      case ChartRange.lastHour:
        return '1H';
      case ChartRange.last24Hours:
        return '24H';
      case ChartRange.last7Days:
        return '7D';
      case ChartRange.last30Days:
        return '30D';
      case ChartRange.last90Days:
        return '90D';
    }
  }
}
