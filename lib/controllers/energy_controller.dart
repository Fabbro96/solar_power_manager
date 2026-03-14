import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/energy_data.dart';
import '../models/power_sample.dart';
import '../services/app_log_service.dart';
import '../services/energy_service.dart';
import '../services/power_history_service.dart';
import '../services/version_check_service.dart';

class InverterIpProbeResult {
  final bool success;
  final String message;

  const InverterIpProbeResult._({
    required this.success,
    required this.message,
  });

  const InverterIpProbeResult.success(String message)
      : this._(success: true, message: message);

  const InverterIpProbeResult.failure(String message)
      : this._(success: false, message: message);
}

class EnergyController extends ChangeNotifier {
  static const int _pruneEverySamples = 24;
  static const Duration _internetCheckInterval = Duration(minutes: 10);

  final EnergyService _service;
  final PowerHistoryService? _historyService;
  final AppConfig _config;
  final AppLogService _logs;
  late final VersionCheckService _versionCheck;

  MonitorState _state = const MonitorState();

  MonitorState get state => _state;

  GitHubRelease? _availableRelease;
  Timer? _versionCheckTimer;

  GitHubRelease? get availableRelease => _availableRelease;

  List<PowerSample> _powerHistory = [];

  Timer? _fetchTimer;
  double _lastViewportWidth = 0;
  DateTime? _lastStoredSampleAt;
  DateTime? _lastInternetCheckAt;
  double? _lastPowerReading;
  Duration _currentFetchInterval = const Duration(seconds: 30);
  int _rangeRequestId = 0;
  int _fetchGeneration = 0;
  bool _hasFreshReading = false;
  int _samplesSincePrune = 0;
  int _stableSampleStreak = 0;
  int _errorStreak = 0;
  bool _isFetching = false;
  bool _started = false;
  bool _disposed = false;

  EnergyController({
    required EnergyService service,
    PowerHistoryService? historyService,
    AppConfig config = const AppConfig(),
    AppLogService? logService,
    String appVersion = '2.0.0',
  })  : _service = service,
        _historyService = historyService,
        _config = config,
        _logs = logService ?? AppLogService() {
    _versionCheck = VersionCheckService(localVersion: appVersion);
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _currentFetchInterval = _config.fetchInterval;
    _logs.info('EnergyController', 'Monitoring started');

    unawaited(_loadChartRange(_state.chartRange));
    _scheduleNextFetch(immediate: true);
  }

  void stop() {
    _fetchTimer?.cancel();
    _fetchTimer = null;
    _started = false;
    _logs.debug('EnergyController', 'Monitoring stopped');
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _versionCheckTimer?.cancel();
    _logs.info('EnergyController', 'Controller disposed');
    _service.dispose();
    _logs.dispose();
    unawaited(_historyService?.dispose());
    super.dispose();
  }

  Future<void> refresh() async {
    if (_disposed || !_started || _isFetching) return;

    _isFetching = true;
    final gen = _fetchGeneration;
    try {
      await _fetchEnergy();

      if (gen != _fetchGeneration || _disposed || !_started) return;

      final now = DateTime.now();
      final shouldCheckInternet = _lastInternetCheckAt == null ||
          now.difference(_lastInternetCheckAt!) >= _internetCheckInterval;

      if (shouldCheckInternet) {
        _lastInternetCheckAt = now;
        await _checkInternet();
      }
    } finally {
      _isFetching = false;
      if (gen == _fetchGeneration) {
        _scheduleNextFetch();
      }
    }
  }

  String get currentInverterIp {
    final uri = Uri.tryParse(_service.config.url);
    return uri?.host ?? '';
  }

  String get currentUsername => _service.config.username;
  String get currentPassword => _service.config.password;

  AppLogEntry? get latestLog => _logs.latest;
  List<AppLogEntry> get recentLogs => _logs.entries;

  /// Returns the current on-disk log file path, if available.
  String? get logFilePath => _logs.logFilePath;

  Future<String> readAllLogs() => _logs.readAll();

  Future<void> clearLogs() => _logs.clear();

  Future<InverterIpProbeResult> probeInverterConfig({
    required String ip,
    required String username,
    required String password,
  }) async {
    final normalized = EnergyService.normalizeIpv4(ip);
    if (normalized == null) {
      _logs.warning('EnergyController', 'Rejected invalid IP: "$ip"');
      return const InverterIpProbeResult.failure('Formato IP non valido');
    }

    try {
      final data = await _service.probeInverterConfig(
        ip: normalized,
        username: username,
        password: password,
      );
      if (data.latestPowerValue == null &&
          data.powerNow == 'N/A' &&
          data.todaysEnergy == 'N/A') {
        _logs.warning('EnergyController',
            'IP $normalized reachable but inverter payload has no usable values');
        return const InverterIpProbeResult.failure(
          'Connessione ok, ma l\'inverter non ha restituito dati validi',
        );
      }

      _logs.info('EnergyController', 'Config probe successful for $normalized');
      return InverterIpProbeResult.success(
        'Connessione riuscita: ${data.powerNow} / ${data.todaysEnergy}',
      );
    } on EnergyServiceException catch (e) {
      _logs.error('EnergyController',
          'Config probe failed for $normalized: ${e.message}');
      return InverterIpProbeResult.failure('Connessione fallita: ${e.message}');
    } catch (e) {
      _logs.error(
          'EnergyController', 'Config probe crashed for $normalized: $e');
      return InverterIpProbeResult.failure('Errore durante il test: $e');
    }
  }

  Future<void> updateInverterConfig({
    required String ip,
    required String username,
    required String password,
  }) async {
    final normalized = EnergyService.normalizeIpv4(ip);
    if (normalized == null) {
      _logs.warning('EnergyController',
          'updateInverterConfig rejected invalid input: "$ip"');
      throw const EnergyServiceException('Invalid IPv4 address');
    }

    _fetchGeneration++;
    _isFetching = false;
    final previousRange = _state.chartRange;
    _service.updateInverterIp(normalized);
    _service.updateCredentials(username, password);
    _powerHistory = [];
    _hasFreshReading = false;
    _lastStoredSampleAt = null;
    _errorStreak = 0;
    _stableSampleStreak = 0;
    _lastPowerReading = null;
    _lastInternetCheckAt = null;

    _logs.info('EnergyController',
        'Applying config for IP $normalized and restarting polling');
    updateState(MonitorState(chartRange: previousRange));
    stop();
    start();
  }

  /// Check periodically for new app version on GitHub.
  Future<void> scheduleVersionCheck() async {
    if (_disposed) return;

    // Check immediately on first call
    await checkForUpdate();

    // Then check every 24 hours
    _versionCheckTimer = Timer.periodic(const Duration(hours: 24), (_) async {
      await checkForUpdate();
    });
  }

  Future<bool> checkForUpdate() async {
    if (_disposed) return false;
    try {
      final release = await _versionCheck.getLatestRelease();
      if (release == null || _disposed) return false;

      if (_versionCheck.isUpdateAvailable(release.tagName)) {
        _logs.info('EnergyController',
            'New version ${release.tagName} available (current: 2.0.0)');
        _availableRelease = release;
        notifyListeners();
        return true;
      } else {
        _availableRelease = null;
        notifyListeners();
      }
    } catch (e) {
      _logs.debug('EnergyController', 'Version check failed: $e');
    }
    return false;
  }

  /// Download the latest available APK (if any) for this device.
  ///
  /// Returns the local file path where the APK was saved, or null if download
  /// failed or no APK was available.
  Future<String?> downloadLatestApk() async {
    if (_disposed) return null;

    if (_availableRelease == null) {
      await checkForUpdate();
    }

    final release = _availableRelease;
    if (release == null) return null;

    final arch = VersionCheckService.getDeviceArch();
    final apkUrl = release.getApkForArch(arch) ?? release.apkUrl;
    if (apkUrl == null) return null;

    final file = await _versionCheck.downloadApk(apkUrl, arch);
    return file?.path;
  }

  void dismissUpdateNotification() {
    if (_disposed) return;
    _availableRelease = null;
    notifyListeners();
  }

  void updateState(MonitorState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  Future<void> setChartRange(ChartRange range) async {
    if (_state.chartRange == range) return;
    await _loadChartRange(range);
  }

  void updateViewportWidth(double width) {
    if (width <= 0) return;
    // cadence is read from _lastViewportWidth on the next _pushChartPoint call
    _lastViewportWidth = width;
  }

  Duration _chartCadenceForRange(ChartRange range) {
    final base = _baseCadenceForRange(range);
    final viewportClass = _viewportClass(_lastViewportWidth);

    if (viewportClass == _ViewportClass.compact) {
      return Duration(minutes: base.inMinutes * 2);
    }
    if (viewportClass == _ViewportClass.expanded) {
      final reducedMinutes = (base.inMinutes / 2).round();
      final floorMinutes = _baseCadenceForRange(ChartRange.lastHour).inMinutes;
      return Duration(
          minutes:
              reducedMinutes < floorMinutes ? floorMinutes : reducedMinutes);
    }

    return base;
  }

  Duration _baseCadenceForRange(ChartRange range) {
    switch (range) {
      case ChartRange.lastHour:
        return const Duration(minutes: 5);
      case ChartRange.last24Hours:
        return const Duration(minutes: 30);
      case ChartRange.last7Days:
        return const Duration(hours: 3);
      case ChartRange.last30Days:
        return const Duration(hours: 12);
      case ChartRange.last90Days:
        return const Duration(days: 1);
    }
  }

  _ViewportClass _viewportClass(double width) {
    if (width <= 0) return _ViewportClass.regular;
    if (width < 520) return _ViewportClass.compact;
    if (width > 1200) return _ViewportClass.expanded;
    return _ViewportClass.regular;
  }

  Future<void> _fetchEnergy() async {
    final gen = _fetchGeneration;
    try {
      final data = await _service.fetchEnergyData();
      if (gen != _fetchGeneration || _disposed) return;

      _hasFreshReading = data.latestPowerValue != null;
      _errorStreak = 0;
      _adjustFetchIntervalForReading(data.latestPowerValue);
      _logs.debug(
        'EnergyController',
        'Fetch success: power=${data.powerNow}, today=${data.todaysEnergy}',
      );
      updateState(_state.copyWith(
        energyData: data,
        inverterStatus: ConnectionStatus.connected,
        errorDetail: null,
      ));

      // Capture chart points on successful fetch so history starts immediately
      // and does not depend on timer alignment.
      _pushChartPoint();
    } on EnergyServiceException catch (e) {
      if (gen != _fetchGeneration || _disposed) return;
      _hasFreshReading = false;
      _adjustFetchIntervalForError();
      _logs.warning('EnergyController', 'Fetch error: ${e.message}');
      updateState(_state.copyWith(
        inverterStatus: ConnectionStatus.error,
        errorDetail: e.message,
      ));
    } catch (e) {
      if (gen != _fetchGeneration || _disposed) return;
      _hasFreshReading = false;
      _adjustFetchIntervalForError();
      _logs.error('EnergyController', 'Unexpected fetch error: $e');
      updateState(_state.copyWith(
        inverterStatus: ConnectionStatus.error,
        errorDetail: e.toString(),
      ));
    }
  }

  void _scheduleNextFetch({bool immediate = false}) {
    if (_disposed || !_started) return;

    _fetchTimer?.cancel();
    _fetchTimer = Timer(
      immediate ? Duration.zero : _currentFetchInterval,
      () => unawaited(refresh()),
    );
  }

  void _adjustFetchIntervalForReading(double? reading) {
    if (reading == null) {
      _stableSampleStreak = 0;
      _currentFetchInterval = _config.fetchInterval;
      _lastPowerReading = null;
      return;
    }

    final previous = _lastPowerReading;
    _lastPowerReading = reading;

    if (previous == null) {
      _stableSampleStreak = 0;
      _currentFetchInterval = _config.fetchInterval;
      return;
    }

    final delta = (reading - previous).abs();
    if (delta <= _config.stableDeltaThresholdWatts) {
      _stableSampleStreak++;
    } else {
      _stableSampleStreak = 0;
      _currentFetchInterval = _config.minFetchInterval;
      return;
    }

    if (_stableSampleStreak >= _config.stableSamplesForBackoff) {
      final expanded = Duration(
        milliseconds: (_currentFetchInterval.inMilliseconds * 1.35).round(),
      );
      _currentFetchInterval = expanded > _config.maxFetchInterval
          ? _config.maxFetchInterval
          : expanded;
    } else {
      _currentFetchInterval = _config.fetchInterval;
    }
  }

  void _adjustFetchIntervalForError() {
    _errorStreak++;
    _stableSampleStreak = 0;

    final multiplier = _errorStreak < 4 ? _errorStreak + 1 : 4;
    final expanded = Duration(
      milliseconds: _config.fetchInterval.inMilliseconds * multiplier,
    );
    _currentFetchInterval = expanded > _config.maxFetchInterval
        ? _config.maxFetchInterval
        : expanded;
  }

  Future<void> _checkInternet() async {
    try {
      final ok = await _service.checkInternetConnectivity();
      if (_disposed) return;
      final internetStatus =
          ok ? ConnectionStatus.connected : ConnectionStatus.error;
      _logs.debug(
          'EnergyController', 'Internet check: ${ok ? 'ok' : 'failed'}');
      updateState(_state.copyWith(
        internetStatus: internetStatus,
      ));
    } catch (e) {
      if (_disposed) return;
      _logs.warning('EnergyController', 'Internet check failed: $e');
      updateState(_state.copyWith(
        internetStatus: ConnectionStatus.error,
        errorDetail: 'Internet check failed: ${e.toString()}',
      ));
    }
  }

  void _pushChartPoint() {
    try {
      if (!_hasFreshReading) return;

      final power = _state.energyData.latestPowerValue;
      if (power == null) return;

      final now = DateTime.now();
      final cadence = _chartCadenceForRange(_state.chartRange);
      if (_lastStoredSampleAt != null &&
          now.difference(_lastStoredSampleAt!) < cadence) {
        return;
      }

      final sample = PowerSample(timestamp: now, watts: power);
      _lastStoredSampleAt = now;
      _hasFreshReading = false;
      unawaited(_persistSample(sample));

      final cutoff = now.subtract(_state.chartRange.duration);
      if (sample.timestamp.isBefore(cutoff)) {
        return;
      }

      _powerHistory = _appendWithinRangeAndCap(
        existing: _powerHistory,
        sample: sample,
        cutoff: cutoff,
        maxPoints: _config.maxChartPoints,
      );

      updateState(_state.copyWith(powerHistory: _powerHistory));
    } catch (e) {
      _logs.warning('EnergyController', 'Chart point update failed: $e');
    }
  }

  Future<void> _loadChartRange(ChartRange range) async {
    final requestId = ++_rangeRequestId;
    updateState(_state.copyWith(chartRange: range, chartLoading: true));

    try {
      final loaded = await _historyService?.loadRange(range: range) ??
          const <PowerSample>[];
      if (requestId != _rangeRequestId || _disposed) return;

      _powerHistory = _downsample(loaded, maxPoints: _config.maxChartPoints);
      _lastStoredSampleAt = loaded.isNotEmpty ? loaded.last.timestamp : null;
      updateState(_state.copyWith(
        chartRange: range,
        chartLoading: false,
        powerHistory: _powerHistory,
      ));
    } catch (e) {
      if (requestId != _rangeRequestId || _disposed) return;
      _logs.warning('EnergyController', 'History load failed: $e');

      updateState(_state.copyWith(
        chartRange: range,
        chartLoading: false,
        errorDetail: 'History load failed: ${e.toString()}',
      ));
    }
  }

  Future<void> _persistSample(PowerSample sample) async {
    try {
      await _historyService?.insertSample(sample);
      if (_disposed) return;
      _samplesSincePrune++;
      if (_samplesSincePrune >= _pruneEverySamples) {
        _samplesSincePrune = 0;
        await _historyService?.pruneOldSamples();
      }
    } catch (e) {
      if (_disposed) return;
      _logs.warning('EnergyController', 'History save failed: $e');
    }
  }

  List<PowerSample> _downsample(
    List<PowerSample> samples, {
    required int maxPoints,
  }) {
    if (maxPoints <= 1 || samples.length <= maxPoints) return samples;

    final result = <PowerSample>[];
    final step = (samples.length - 1) / (maxPoints - 1);

    for (var i = 0; i < maxPoints; i++) {
      final index = (i * step).round();
      result.add(samples[index]);
    }

    return result;
  }

  List<PowerSample> _appendWithinRangeAndCap({
    required List<PowerSample> existing,
    required PowerSample sample,
    required DateTime cutoff,
    required int maxPoints,
  }) {
    final filtered = existing.where((s) => !s.timestamp.isBefore(cutoff));
    final next = List<PowerSample>.of(filtered, growable: true)..add(sample);
    if (next.length <= maxPoints) {
      return next;
    }
    return next.sublist(next.length - maxPoints);
  }
}

enum _ViewportClass {
  compact,
  regular,
  expanded,
}
