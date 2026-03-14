import 'package:flutter_test/flutter_test.dart';
import 'package:solar_power_manager/services/version_check_service.dart';

void main() {
  test('VersionCheckService compares versions correctly', () {
    final service = VersionCheckService(localVersion: '2.0.0');

    expect(service.isUpdateAvailable('2.0.1'), true);
    expect(service.isUpdateAvailable('2.1.0'), true);
    expect(service.isUpdateAvailable('2.1'), true); // Check 0.1 format
    expect(service.isUpdateAvailable('3.0.0'), true);
    expect(service.isUpdateAvailable('3.0'), true);
    expect(service.isUpdateAvailable('2.0.0'), false);
    expect(service.isUpdateAvailable('2.0'), false);
    expect(service.isUpdateAvailable('1.9.9'), false);
    expect(service.isUpdateAvailable('1.9'), false);
  });

  test('VersionCheckService gets correct APK URL for architecture', () {
    final release = GitHubRelease(
      tagName: 'v2.1.0',
      apkArm64Url: 'https://example.com/arm64.apk',
      apkArmv7Url: 'https://example.com/armv7.apk',
      apkX86Url: 'https://example.com/x86.apk',
      apkX86_64Url: 'https://example.com/x86_64.apk',
    );

    expect(release.getApkForArch('arm64'), 'https://example.com/arm64.apk');
    expect(release.getApkForArch('armv7'), 'https://example.com/armv7.apk');
    expect(release.getApkForArch('x86'), 'https://example.com/x86.apk');
    expect(release.getApkForArch('x86_64'), 'https://example.com/x86_64.apk');
  });
}
