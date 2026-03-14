import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_power_manager/services/app_log_service.dart';

void main() {
  test('AppLogService can write/read/clear logs on disk', () async {
    final tempDir = await Directory.systemTemp.createTemp('apl_log_test_');
    final logService = AppLogService(maxEntries: 10, flushDelay: Duration.zero);

    await logService.init(basePath: tempDir.path);
    logService.info('test', 'first');
    logService.error('test', 'second');

    // Ensure any pending writes are flushed before reading.
    await logService.flush();
    final content = await logService.readAll();
    expect(content, contains('first'));
    expect(content, contains('second'));

    await logService.clear();
    final afterClear = await logService.readAll();
    expect(afterClear.trim(), isEmpty);

    await tempDir.delete(recursive: true);
  });

  test(
      'AppLogService handles concurrent writes without deadlocks or missing data',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('apl_log_concurrency_');
    // Using an instant flush to stress the overlapping flush checks
    final logService =
        AppLogService(maxEntries: 200, flushDelay: Duration.zero);
    await logService.init(basePath: tempDir.path);

    // Simulate 100 simultaneous calls
    final futures = <Future>[];
    for (int i = 0; i < 100; i++) {
      futures.add(
          Future.microtask(() => logService.info('Concurrency', 'Message $i')));
    }

    await Future.wait(futures);
    await logService.flush();

    final content = await logService.readAll();
    for (int i = 0; i < 100; i++) {
      expect(content, contains('Message $i'));
    }

    await tempDir.delete(recursive: true);
  });

  test(
      'AppLogService redacts sensitive info if present intentionally/unintentionally',
      () {
    final logService =
        AppLogService(maxEntries: 200, flushDelay: Duration.zero);
    logService.info('Security', 'Trying password=super_secret!');
    expect(logService.entries.last.message, 'Trying password=***');

    logService.info('Network', 'url: http://user:password=1234@ip');
    expect(logService.entries.last.message, 'url: http://user:password=***');
  });
}
