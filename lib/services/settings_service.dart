import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages runtime inverter settings.
///
/// Default configuration is read from [assets/inverter_defaults.json].
/// IP and credentials can be overridden and are persisted across
/// restarts via [SharedPreferences].
class SettingsService {
  static const _ipKey = 'inverter_ip';
  static const _usernameKey = 'inverter_username';
  static const _passwordKey = 'inverter_password';

  final SharedPreferences _prefs;
  final String _defaultIp;
  final String _inverterPath;
  final String _defaultUsername;
  final String _defaultPassword;

  SettingsService._({
    required SharedPreferences prefs,
    required String defaultIp,
    required String inverterPath,
    required String defaultUsername,
    required String defaultPassword,
  })  : _prefs = prefs,
        _defaultIp = defaultIp,
        _inverterPath = inverterPath,
        _defaultUsername = defaultUsername,
        _defaultPassword = defaultPassword;

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    late final Map<String, dynamic> defaults;
    try {
      final raw = await rootBundle.loadString('assets/inverter_defaults.json');
      defaults = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw StateError(
        'Failed to load inverter_defaults.json: $e. '
        'Ensure the asset exists and is valid JSON.',
      );
    }
    final requiredKeys = [
      'default_ip',
      'inverter_path',
      'username',
      'password'
    ];
    for (final key in requiredKeys) {
      if (!defaults.containsKey(key)) {
        throw StateError(
            'inverter_defaults.json is missing required key: "$key"');
      }
    }
    return SettingsService._(
      prefs: prefs,
      defaultIp: defaults['default_ip'] as String,
      inverterPath: defaults['inverter_path'] as String,
      defaultUsername: defaults['username'] as String,
      defaultPassword: defaults['password'] as String,
    );
  }

  String get inverterIp => _prefs.getString(_ipKey) ?? _defaultIp;
  String get username => _prefs.getString(_usernameKey) ?? _defaultUsername;
  String get password => _prefs.getString(_passwordKey) ?? _defaultPassword;

  String get inverterUrl => 'http://$inverterIp$_inverterPath';

  Future<void> setInverterIp(String ip) => _prefs.setString(_ipKey, ip);
  Future<void> setUsername(String un) => _prefs.setString(_usernameKey, un);
  Future<void> setPassword(String pw) => _prefs.setString(_passwordKey, pw);
}
