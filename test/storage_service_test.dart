import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpn/services/storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists notification settings', () async {
    final store = StorageService();

    await store.saveStatusNotification(false);
    await store.saveLastConnectedNodeUrl('vless://example');

    expect(await store.loadStatusNotification(), isFalse);
    expect(await store.loadLastConnectedNodeUrl(), 'vless://example');
  });

  test('persists proxy apps settings', () async {
    final store = StorageService();

    await store.saveProxyAppsEnabled(true);
    await store.saveProxyAppsList(['com.a', 'com.b']);

    expect(await store.loadProxyAppsEnabled(), isTrue);
    expect(await store.loadProxyAppsList(), ['com.a', 'com.b']);
  });
}
