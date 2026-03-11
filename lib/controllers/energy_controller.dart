import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/energy_data.dart';
import '../models/power_sample.dart';
import '../services/energy_service.dart';
import '../services/power_history_service.dart';

class EnergyController extends ChangeNotifier {
  static const int _maxVisiblePoints = 480;
  static const int _pruneEverySamples = 24;

  final EnergyService _service;
  final PowerHistoryService? _historyService;
  final AppConfig _config;

  MonitorState _state = const MonitorState();

  MonitorState get state => _state;

  List<PowerSample> _powerHistory = [];

  Timer? _fetchTimer;
  Timer? _chartTimer;
  int _rangeRequestId = 0;
  bool _hasFreshReading = false;
  int _samplesSincePrune = 0;

  EnergyController({
    required EnergyService service,
    PowerHistoryService? historyService,
    AppConfig config = const AppConfig(),
  })  : _service = service,
        _historyService = historyService,
        _config = config;

  void start() {
    unawaited(_loadChartRange(_state.chartRange));
    refresh();
    _fetchTimer = Timer.periodic(_config.fetchInterval, (_) => refresh());
    _chartTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _pushChartPoint());
  }

  void stop() {
    _fetchTimer?.cancel();
    _chartTimer?.cancel();
  }

  @override
  void dispose() {
    stop();
    _service.dispose();
    unawaited(_historyService?.dispose());
    super.dispose();
  }

  Future<void> refresh() async {
    await Future.wait([_fetchEnergy(), _checkInternet()]);
  }

  String get currentInverterIp {
    final uri = Uri.tryParse(_service.config.url);
    return uri?.host ?? '';
  }

  Future<void> updateInverterIp(String newIp) async {
    _service.updateInverterIp(newIp);
    _powerHistory = [];
    _state = const MonitorState();
    notifyListeners();
    stop();
    start();
  }

  void updateState(MonitorState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> setChartRange(ChartRange range) async {
    if (_state.chartRange == range) return;
    await _loadChartRange(range);
  }

  Future<void> _fetchEnergy() async {
    try {
      final data = await _service.fetchEnergyData();
      _hasFreshReading = data.latestPowerValue != null;
      updateState(_state.copyWith(
        energyData: data,
        inverterStatus: ConnectionStatus.connected,
        errorDetail: null,
      ));
    } on EnergyServiceException catch (e) {
      _hasFreshReading = false;
      updateState(_state.copyWith(
        inverterStatus: ConnectionStatus.error,
        errorDetail: e.message,
      ));
    } catch (e) {
      _hasFreshReading = false;
      updateState(_state.copyWith(
        inverterStatus: ConnectionStatus.error,
        errorDetail: e.toString(),
      ));
    }
  }

  Future<void> _checkInternet() async {
    try {
      final ok = await _service.checkInternetConnectivity();
      final internetStatus =
          ok ? ConnectionStatus.connected : ConnectionStatus.error;
      updateState(_state.copyWith(
        internetStatus: internetStatus,
      ));
    } catch (e) {
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

      final sample = PowerSample(timestamp: DateTime.now(), watts: power);
      _hasFreshReading = false;
      unawaited(_persistSample(sample));

      final cutoff = DateTime.now().subtract(_state.chartRange.duration);
      if (sample.timestamp.isBefore(cutoff)) {
        return;
      }

      _powerHistory = _downsample(
        List.of(_powerHistory)..add(sample),
        maxPoints: _maxVisiblePoints,
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
      if (requestId != _rangeRequestId) return;

      _powerHistory = _downsample(loaded, maxPoints: _maxVisiblePoints);
      updateState(_state.copyWith(
        chartRange: range,
        chartLoading: false,
        powerHistory: _powerHistory,
      ));
    } catch (e) {
      if (requestId != _rangeRequestId) return;

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
      _samplesSincePrune++;
      if (_samplesSincePrune >= _pruneEverySamples) {
        _samplesSincePrune = 0;
        await _historyService?.pruneOldSamples();
      }
    } catch (e) {
      updateState(_state.copyWith(
        errorDetail: 'History save failed: ${e.toString()}',
      ));
    }
  }

  List<PowerSample> _downsample(
    List<PowerSample> samples, {
    required int maxPoints,
  }) {
    if (samples.length <= maxPoints) return samples;

    final result = <PowerSample>[];
    final step = (samples.length - 1) / (maxPoints - 1);

    for (var i = 0; i < maxPoints; i++) {
      final index = (i * step).round();
      result.add(samples[index]);
    }

    return result;
  }
}
