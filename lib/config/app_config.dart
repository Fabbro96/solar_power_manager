class AppConfig {
  final Duration fetchInterval;
  final Duration minFetchInterval;
  final Duration maxFetchInterval;
  final double stableDeltaThresholdWatts;
  final int stableSamplesForBackoff;
  final int maxChartPoints;

  const AppConfig({
    // Default polling cadence is slower to reduce CPU/network usage.
    this.fetchInterval = const Duration(minutes: 2),
    this.minFetchInterval = const Duration(minutes: 1),
    this.maxFetchInterval = const Duration(minutes: 15),
    // Increase threshold so small fluctuations don't force faster polling.
    this.stableDeltaThresholdWatts = 40,
    this.stableSamplesForBackoff = 6,
    // Keep chart history reasonable for performance.
    this.maxChartPoints = 40,
  });
}
