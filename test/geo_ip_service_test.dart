import 'package:flutter_test/flutter_test.dart';
import 'package:vpn/services/geo_ip_service.dart';

void main() {
  test('parses success response', () {
    final info = GeoIpService.parseResponse({
      'status': 'success',
      'country': '美国',
      'regionName': '加州',
      'city': '洛杉矶',
      'lat': 34.0544,
      'lon': -118.244,
    });

    expect(info, isNotNull);
    expect(info!.country, '美国');
    expect(info.region, '加州');
    expect(info.city, '洛杉矶');
    expect(info.lat, 34.0544);
    expect(info.lon, -118.244);
  });
}
