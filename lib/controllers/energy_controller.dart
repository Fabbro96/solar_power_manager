import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/energy_data.dart';
import '../services/energy_service.dart';

class EnergyController extends ChangeNotifier {
  final EnergyService _service;
  final AppConfig _config;

  MonitorState _state = const MonitorState();

  MonitorState get state => _state;

  List<FlSpot> _powerHistory = [];
  int _xTick = 0;

  Timer? _fetchTimer;
  Timer? _chartTimer;

  EnergyController({
    required EnergyService service,
    AppConfig config = const AppConfig(),
  })  : _service = service,
        _config = config;

  void start() {
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
    super.dispose();
  }

  Future<void> refresh() async {
    await Future.wait([_fetchEnergy(), _checkInternet()]);
  }

  void updateState(MonitorState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> _fetchEnergy() async {
    try {
      final data = await _service.fetchEnergyData();
      updateState(_state.copyWith(
        energyData: data,
        inverterStatus: ConnectionStatus.connected,
        errorDetail: null,
      ));
    } on EnergyServiceException catch (e) {
      updateState(_state.copyWith(
        inverterStatus: ConnectionStatus.error,
        errorDetail: e.message,
      ));
    } catch (e) {
      updateState(_state.copyWith(
        inverterStatus: ConnectionStatus.error,
        errorDetail: e.toString(),
      ));
    }
  }

  Future<void> _checkInternet() async {
    final ok = await _service.checkInternetConnectivity();
    updateState(_state.copyWith(
      internetStatus: ok ? ConnectionStatus.connected : ConnectionStatus.error,
    ));
  }

  void _pushChartPoint() {
    final power = _state.energyData.latestPowerValue;
    if (power == null) return;

    _powerHistory = List.of(_powerHistory)
      ..add(FlSpot(_xTick.toDouble(), power));

    if (_powerHistory.length > _config.maxChartPoints) {
      _powerHistory.removeAt(0);
    }

    _xTick++;
    updateState(_state.copyWith(powerHistory: _powerHistory));
  }
}
