import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages runtime inverter settings.
///
/// Credentials and path are read once from [assets/inverter_defaults.json]
/// and are never expected to change. The inverter IP is persisted across
/// restarts via [SharedPreferences].
class SettingsService {
  static const _ipKey = 'inverter_ip';

  final SharedPreferences _prefs;
  final String _defaultIp;
  final String _inverterPath;

  final String username;
  final String password;

  SettingsService._({
    required SharedPreferences prefs,
    required String defaultIp,
    required String inverterPath,
    required this.username,
    required this.password,
  })  : _prefs = prefs,
        _defaultIp = defaultIp,
        _inverterPath = inverterPath;

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await rootBundle.loadString('assets/inverter_defaults.json');
    final defaults = jsonDecode(raw) as Map<String, dynamic>;
    return SettingsService._(
      prefs: prefs,
      defaultIp: defaults['default_ip'] as String,
      inverterPath: defaults['inverter_path'] as String,
      username: defaults['username'] as String,
      password: defaults['password'] as String,
    );
  }

  String get inverterIp => _prefs.getString(_ipKey) ?? _defaultIp;

  String get inverterUrl => 'http://$inverterIp$_inverterPath';

  Future<void> setInverterIp(String ip) => _prefs.setString(_ipKey, ip);
}
