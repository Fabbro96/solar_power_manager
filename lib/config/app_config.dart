class AppConfig {
  final Duration fetchInterval;
  final int maxChartPoints;

  const AppConfig({
    this.fetchInterval = const Duration(seconds: 30),
    this.maxChartPoints = 50,
  });
}
