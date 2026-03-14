import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  static const _tagsURL =
      'https://api.github.com/repos/$_owner/$_repo/tags?per_page=100';

  final String _localVersion;

  VersionCheckService({required String localVersion})
      : _localVersion = localVersion;

  /// Fetch the latest release from GitHub.
  Future<GitHubRelease?> getLatestRelease() async {
    try {
      final response = await http.get(Uri.parse(_releaseURL));
      if (response.statusCode == 200) {
        final release = _parseGitHubRelease(response.body);
        if (release != null) {
          // If the release has a semver tag (e.g. v2.0.0), use it directly.
          final semver = _extractSemver(release.tagName);
          if (semver != null) {
            return release;
          }
        }
      }

      // Fallback: If the "latest release" API doesn't return a semver-friendly tag,
      // look for the latest semver tag from the repo's tags list.
      final latestTag = await _getLatestSemverTag();
      if (latestTag != null) {
        return GitHubRelease(tagName: latestTag);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Compare versions (e.g., "2.0.0" vs "2.0.1").
  /// Returns true if remoteVersion > localVersion.
  bool isUpdateAvailable(String remoteVersion) {
    final remoteSemver = _extractSemver(remoteVersion) ?? remoteVersion;
    final localSemver = _extractSemver(_localVersion) ?? _localVersion;
    return _compareVersions(remoteSemver, localSemver) > 0;
  }

  /// Download APK for the given architecture.
  Future<File?> downloadApk(String apkUrl, String arch) async {
    return downloadApkWithProgress(apkUrl, arch);
  }

  /// Download APK for the given architecture, reporting progress.
  Future<File?> downloadApkWithProgress(
    String apkUrl,
    String arch, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'solar_power_manager_$arch.apk';
      final filePath = p.join(dir.path, fileName);
      final file = File(filePath);
      final uri = Uri.parse(apkUrl);

      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);
      if (response.statusCode != 200) return null;

      final contentLength = response.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;

      await response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);
        if (onProgress != null && contentLength > 0) {
          onProgress(received, contentLength);
        }
      }).asFuture();

      await sink.close();
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Get device architecture.
  static String getDeviceArch() {
    if (!Platform.isAndroid) return 'arm64';

    switch (Abi.current()) {
      case Abi.androidArm64:
        return 'arm64';
      case Abi.androidArm:
        return 'armv7';
      case Abi.androidIA32:
        return 'x86';
      case Abi.androidX64:
        return 'x86_64';
      default:
        return 'arm64';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  GitHubRelease? _parseGitHubRelease(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final rawTagName = json['tag_name'] as String?;
      final name = json['name'] as String?;
      if (rawTagName == null) return null;

      // Se il tag_name è qualcosa type "stable", proviamo a cercare la versione
      // all'interno del nome della release (es. "Stable - v1.0.0").
      String tagName = rawTagName;
      if (_extractSemver(rawTagName) == null &&
          name != null &&
          _extractSemver(name) != null) {
        tagName = name;
      }

      String? apkUrl;
      String? apkArm64Url;
      String? apkArmv7Url;
      String? apkX86Url;
      String? apkX86_64Url;

      final assets = json['assets'] as List<dynamic>?;
      if (assets != null) {
        for (final asset in assets.cast<Map<String, dynamic>>()) {
          final url = asset['browser_download_url'] as String?;
          if (url == null) continue;

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

  String? _extractSemver(String tag) {
    // Finds version patterns like "v2.1", "v1.2.3" or "1.2.3".
    final match = RegExp(r'v?(\d+\.\d+(?:\.\d+)?)').firstMatch(tag);
    return match?.group(1);
  }

  Future<String?> _getLatestSemverTag() async {
    try {
      final response = await http.get(Uri.parse(_tagsURL));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as List<dynamic>;
      String? best;
      for (final entry in json.cast<Map<String, dynamic>>()) {
        final name = entry['name'] as String?;
        if (name == null) continue;

        final semver = _extractSemver(name);
        if (semver == null) continue;

        if (best == null || _compareVersions(semver, best) > 0) {
          best = semver;
        }
      }
      return best;
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
