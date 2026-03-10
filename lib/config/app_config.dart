class AppConfig {
  final String inverterUrl;
  final String username;
  final String password;
  final Duration fetchInterval;
  final int maxChartPoints;

  const AppConfig({
    this.inverterUrl = 'http://192.168.1.16/monitor.htm',
    this.username = 'admin',
    this.password = 'admin',
    this.fetchInterval = const Duration(seconds: 30),
    this.maxChartPoints = 50,
  });

  // Example of customizable variants if needed
  static const fallback = AppConfig();
}
