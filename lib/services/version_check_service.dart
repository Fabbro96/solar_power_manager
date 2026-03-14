import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class GitHubRelease {
  final String tagName;
  final String? apkUrl;
  final String? apkArm64Url;
  final String? apkArmv7Url;
  final String? apkX86Url;
  final String? apkX86_64Url;

  GitHubRelease({
    required this.tagName,
    this.apkUrl,
    this.apkArm64Url,
    this.apkArmv7Url,
    this.apkX86Url,
    this.apkX86_64Url,
  });

  String? getApkForArch(String arch) {
    switch (arch) {
      case 'arm64':
        return apkArm64Url;
      case 'armv7':
        return apkArmv7Url;
      case 'x86':
        return apkX86Url;
      case 'x86_64':
        return apkX86_64Url;
      default:
        return apkUrl; // fallback
    }
  }
}

class VersionCheckService {
  static const _owner = 'Fabbro96';
  static const _repo = 'solar_power_manager';
  static const _releaseURL =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  final String _localVersion;

  VersionCheckService({required String localVersion})
      : _localVersion = localVersion;

  /// Fetch the latest release from GitHub.
  Future<GitHubRelease?> getLatestRelease() async {
    try {
      final response = await http.get(Uri.parse(_releaseURL));
      if (response.statusCode != 200) return null;

      final json = response.body;
      return _parseGitHubRelease(json);
    } catch (_) {
      return null;
    }
  }

  /// Compare versions (e.g., "2.0.0" vs "2.0.1").
  /// Returns true if remoteVersion > localVersion.
  bool isUpdateAvailable(String remoteVersion) {
    return _compareVersions(remoteVersion, _localVersion) > 0;
  }

  /// Download APK for the given architecture.
  Future<File?> downloadApk(String apkUrl, String arch) async {
    try {
      final dir = await getDatabasesPath();
      final fileName = 'solar_power_manager_$arch.apk';
      final filePath = p.join(dir, fileName);
      final file = File(filePath);

      final response = await http.get(Uri.parse(apkUrl));
      if (response.statusCode != 200) return null;

      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Get device architecture.
  static String getDeviceArch() {
    // On Android, you'd use Platform.operatingSystemVersion or native code.
    // For now, return a safe default or read from native side.
    return 'arm64'; // default for most modern devices
  }

  // ── Helpers ────────────────────────────────────────────────────────

  GitHubRelease? _parseGitHubRelease(String jsonStr) {
    try {
      // Simple JSON parsing (avoiding json dependency)
      final tagMatch =
          RegExp(r'"tag_name"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
      if (tagMatch == null) return null;

      final tagName = tagMatch.group(1)!;

      // Extract asset URLs
      String? apkUrl;
      String? apkArm64Url;
      String? apkArmv7Url;
      String? apkX86Url;
      String? apkX86_64Url;

      final assetsMatch =
          RegExp(r'"assets"\s*:\s*\[([^\]]+)\]').firstMatch(jsonStr);
      if (assetsMatch != null) {
        final assetsStr = assetsMatch.group(1)!;
        final downloads = RegExp(r'"browser_download_url"\s*:\s*"([^"]+)"')
            .allMatches(assetsStr)
            .map((m) => m.group(1)!)
            .toList();

        for (final url in downloads) {
          if (url.contains('arm64')) {
            apkArm64Url = url;
          } else if (url.contains('armv7')) {
            apkArmv7Url = url;
          } else if (url.contains('x86_64')) {
            apkX86_64Url = url;
          } else if (url.contains('x86')) {
            apkX86Url = url;
          } else if (url.endsWith('.apk')) {
            apkUrl = url;
          }
        }
      }

      return GitHubRelease(
        tagName: tagName,
        apkUrl: apkUrl,
        apkArm64Url: apkArm64Url,
        apkArmv7Url: apkArmv7Url,
        apkX86Url: apkX86Url,
        apkX86_64Url: apkX86_64Url,
      );
    } catch (_) {
      return null;
    }
  }

  static int _compareVersions(String v1, String v2) {
    String cleanV1 = v1.replaceAll(RegExp(r'^[vV]'), '').split('+').first;
    String cleanV2 = v2.replaceAll(RegExp(r'^[vV]'), '').split('+').first;

    final p1 = cleanV1.split('.').map(int.tryParse).toList();
    final p2 = cleanV2.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final n1 = i < p1.length && p1[i] != null ? p1[i]! : 0;
      final n2 = i < p2.length && p2[i] != null ? p2[i]! : 0;
      if (n1 > n2) return 1;
      if (n1 < n2) return -1;
    }
    return 0;
  }
}
