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

    test('compares build numbers when version name matches', () {
      expect(AppUpdateService.isNewerVersion('1.0.1+2', '1.0.1+1'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.0.1+1', '1.0.1+1'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.1+1', '1.0.1+2'), isFalse);
      expect(AppUpdateService.isNewerVersion('v1.0.2', '1.0.1+9'), isTrue);
    });
  });
}
