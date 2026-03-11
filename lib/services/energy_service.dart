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

  EnergyService({required EnergyServiceConfig config, http.Client? client})
      : _config = config,
        _client = client ?? http.Client();

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
      final credentials = '${config.username}:${config.password}';
      final encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await _client.get(
        Uri.parse(config.url),
        headers: {'Authorization': 'Basic $encodedCredentials'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw EnergyServiceException(
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final todaysEnergy = _extractValueRegex(response.body, "Today's Energy");
      final powerNow = _extractValueRegex(response.body, 'Power Now');
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
      final response = await _client
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String _extractValueRegex(String html, String keyword) {
    // Looks for <td>Keyword:</td> then capturing the following <td>content</td>
    final regex = RegExp('<td>\\s*$keyword:\\s*</td>\\s*<td>(.*?)</td>',
        caseSensitive: false);
    final match = regex.firstMatch(html);
    if (match != null) {
      final val = match.group(1) ?? 'N/A';
      return val.trim();
    }
    return 'N/A';
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
