class AppConfig {
  final Duration fetchInterval;
  final Duration minFetchInterval;
  final Duration maxFetchInterval;
  final double stableDeltaThresholdWatts;
  final int stableSamplesForBackoff;
  final int maxChartPoints;

  const AppConfig({
    this.fetchInterval = const Duration(seconds: 30),
    this.minFetchInterval = const Duration(seconds: 30),
    this.maxFetchInterval = const Duration(minutes: 4),
    this.stableDeltaThresholdWatts = 20,
    this.stableSamplesForBackoff = 4,
    this.maxChartPoints = 50,
  });
}
