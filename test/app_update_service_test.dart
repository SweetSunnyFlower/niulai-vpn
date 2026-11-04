import 'package:flutter_test/flutter_test.dart';
import 'package:vpn/services/app_update_service.dart';

void main() {
  test('parses update response', () {
    final info = AppUpdateInfo.fromJson({
      'version': '1.1.0',
      'force_update': true,
      'download_url': 'https://example.com/vpn.apk',
      'release_notes': '修复问题',
    });

    expect(info, isNotNull);
    expect(info!.version, '1.1.0');
    expect(info.forceUpdate, isTrue);
    expect(info.downloadUrl, 'https://example.com/vpn.apk');
    expect(info.releaseNotes, '修复问题');
  });

  test('rejects response without download url', () {
    final info = AppUpdateInfo.fromJson({
      'version': '1.1.0',
      'force_update': true,
    });

    expect(info, isNull);
  });
}
