import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/energy_data.dart';

class EnergyServiceConfig {
  final String url;
  final String username;
  final String password;

  const EnergyServiceConfig({
    required this.url,
    required this.username,
    required this.password,
  });
}

class EnergyService {
  EnergyServiceConfig _config;
  final http.Client _client;
  late String _authHeader;

  // Pre-compiled regex constants — avoids re-compilation on every call.
  static final _powerRegex =
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*W\b', caseSensitive: false);
  static final _kwhRegex =
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*kWh\b', caseSensitive: false);
  static final _cellRegex = RegExp(
    r'<t[dh][^>]*>(.*?)</t[dh]>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _htmlTagRegex = RegExp(r'<[^>]+>');
  static final _whitespaceRegex = RegExp(r'\s+');

  EnergyService({required EnergyServiceConfig config, http.Client? client})
      : _config = config,
        _client = client ?? http.Client() {
    _authHeader = _buildAuthHeader(config);
  }

  static String _buildAuthHeader(EnergyServiceConfig config) {
    final credentials = '${config.username}:${config.password}';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  EnergyServiceConfig get config => _config;

  /// Swaps only the host of the URL, keeping path and credentials intact.
  void updateInverterIp(String newIp) {
    final uri = Uri.parse(_config.url);
    final newUrl = uri.replace(host: newIp).toString();
    _config = EnergyServiceConfig(
      url: newUrl,
      username: _config.username,
      password: _config.password,
    );
  }

  Future<EnergyData> fetchEnergyData() async {
    try {
      final response = await _client.get(
        Uri.parse(config.url),
        headers: {'Authorization': _authHeader},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw EnergyServiceException(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final todaysEnergy = _extractValue(response.body,
          labels: const ["Today's Energy", 'Today']);
      final powerNow = _extractValue(response.body,
          labels: const ['Power Now', 'Current Power']);
      final numericPower =
          double.tryParse(powerNow.replaceAll(RegExp(r'[^0-9.]'), ''));

      return EnergyData(
        todaysEnergy: todaysEnergy,
        powerNow: powerNow,
        lastUpdate: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
        latestPowerValue: numericPower,
      );
    } on EnergyServiceException {
      rethrow;
    } catch (e) {
      throw EnergyServiceException(
        'Failed to fetch energy data: ${e.toString()}',
      );
    }
  }

  Future<bool> checkInternetConnectivity() async {
    try {
      // HEAD avoids downloading the response body (~200 KB for google.com).
      final response = await _client
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  String _extractValue(String html, {required List<String> labels}) {
    final fromTable = _extractFromTableCells(html, labels);
    if (fromTable != null && fromTable.isNotEmpty) {
      return fromTable;
    }

    // Fallback for pages that render values in free text or scripts.
    if (labels.any((l) => l.toLowerCase().contains('power'))) {
      final power = _powerRegex.firstMatch(html)?.group(1);
      if (power != null) return '$power W';
    }

    if (labels.any((l) => l.toLowerCase().contains('today'))) {
      final energy = _kwhRegex.firstMatch(html)?.group(1);
      if (energy != null) return '$energy kWh';
    }

    return 'N/A';
  }

  String? _extractFromTableCells(String html, List<String> labels) {
    final normalizedLabels = labels.map(_normalizeLabel).toSet();

    final cells = _cellRegex
        .allMatches(html)
        .map((m) => _stripHtml(m.group(1) ?? ''))
        .where((s) => s.isNotEmpty)
        .toList();

    for (var i = 0; i < cells.length - 1; i++) {
      if (normalizedLabels.contains(_normalizeLabel(cells[i]))) {
        return cells[i + 1];
      }
    }

    return null;
  }

  String _normalizeLabel(String value) {
    return value
        .replaceAll(':', '')
        .replaceAll(_whitespaceRegex, ' ')
        .trim()
        .toLowerCase();
  }

  String _stripHtml(String input) {
    return input
        .replaceAll(_htmlTagRegex, ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(_whitespaceRegex, ' ')
        .trim();
  }

  void dispose() {
    _client.close();
  }
}

class EnergyServiceException implements Exception {
  final String message;
  final int? statusCode;

  const EnergyServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'EnergyServiceException: $message';
}
