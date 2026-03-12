import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/energy_data.dart';
import '../models/power_sample.dart';
import '../services/energy_service.dart';
import '../services/power_history_service.dart';

class EnergyController extends ChangeNotifier {
  static const int _pruneEverySamples = 24;
  static const Duration _internetCheckInterval = Duration(minutes: 5);

  final EnergyService _service;
  final PowerHistoryService? _historyService;
  final AppConfig _config;

  MonitorState _state = const MonitorState();

  MonitorState get state => _state;

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
  })  : _service = service,
        _historyService = historyService,
        _config = config;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _currentFetchInterval = _config.fetchInterval;

    unawaited(_loadChartRange(_state.chartRange));
    _scheduleNextFetch(immediate: true);
  }

  void stop() {
    _fetchTimer?.cancel();
    _fetchTimer = null;
    _started = false;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _service.dispose();
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

  Future<void> updateInverterIp(String newIp) async {
    _fetchGeneration++;
    _isFetching = false;
    final previousRange = _state.chartRange;
    _service.updateInverterIp(newIp);
    _powerHistory = [];
    updateState(MonitorState(chartRange: previousRange));
    stop();
    start();
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
      updateState(_state.copyWith(
        inverterStatus: ConnectionStatus.error,
        errorDetail: e.message,
      ));
    } catch (e) {
      if (gen != _fetchGeneration || _disposed) return;
      _hasFreshReading = false;
      _adjustFetchIntervalForError();
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
      updateState(_state.copyWith(
        internetStatus: internetStatus,
      ));
    } catch (e) {
      if (_disposed) return;
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
      updateState(_state.copyWith(
        errorDetail: 'Chart point update failed: ${e.toString()}',
      ));
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
      updateState(_state.copyWith(
        errorDetail: 'History save failed: ${e.toString()}',
      ));
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
