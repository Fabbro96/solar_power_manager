import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ApkInstallService {
  static const MethodChannel _channel = MethodChannel(
    'com.fabbro.solarpowermanager/apk_install',
  );

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> canRequestPackageInstalls() async {
    if (!_isAndroid) return true;

    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> requestPackageInstallPermission() async {
    if (!_isAndroid) return true;

    try {
      return await _channel.invokeMethod<bool>(
            'requestPackageInstallPermission',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }
}
