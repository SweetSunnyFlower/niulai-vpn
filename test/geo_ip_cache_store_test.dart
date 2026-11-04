import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpn/services/geo_ip_cache_store.dart';
import 'package:vpn/services/geo_ip_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores and loads geo info', () async {
    final store = GeoIpCacheStore();
    await store.save({
      'example.com': const GeoIpInfo(
        country: '美国',
        region: '加州',
        city: '洛杉矶',
        lat: 34.0544,
        lon: -118.244,
      ),
    });

    final result = await store.load();
    expect(result['example.com']?.country, '美国');
    expect(result['example.com']?.lat, 34.0544);
    expect(result['example.com']?.lon, -118.244);
  });

  test('does not cache unknown geo info', () async {
    final store = GeoIpCacheStore();
    await store.save({
      'unknown.com': const GeoIpInfo(country: '', region: '', city: ''),
    });

    final result = await store.load();
    expect(result.containsKey('unknown.com'), isFalse);
  });
}
