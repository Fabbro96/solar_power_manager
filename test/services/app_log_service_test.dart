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
}
