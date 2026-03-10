import 'dart:convert';

import 'package:html/parser.dart' show parse;
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
  final EnergyServiceConfig config;
  final http.Client _client;

  EnergyService({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  Future<EnergyData> fetchEnergyData() async {
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

    final document = parse(response.body);
    final todaysEnergy = _extractTableValue(document, "Today's Energy");
    final powerNow = _extractTableValue(document, 'Power Now');
    final numericPower =
        double.tryParse(powerNow.replaceAll(RegExp(r'[^0-9.]'), ''));

    return EnergyData(
      todaysEnergy: todaysEnergy,
      powerNow: powerNow,
      lastUpdate: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
      latestPowerValue: numericPower,
    );
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

  String _extractTableValue(dynamic document, String keyword) {
    final elements = document.getElementsByTagName('td');
    for (var i = 0; i < elements.length - 1; i++) {
      if (elements[i].text.trim() == '$keyword:') {
        return elements[i + 1].text.trim();
      }
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
