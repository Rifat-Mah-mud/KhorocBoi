import 'package:flutter_test/flutter_test.dart';
import 'package:khoroboi/core/update/app_update_service.dart';

void main() {
  group('AppUpdateService.isNewerVersion', () {
    test('detects newer semantic versions', () {
      expect(AppUpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(AppUpdateService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('rejects equal or older versions', () {
      expect(AppUpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.0', '1.0.1'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.9.0', '1.10.0'), isFalse);
    });
  });
}
