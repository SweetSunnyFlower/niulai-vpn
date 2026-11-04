import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'geo_ip_service.dart';

class GeoIpCacheStore {
  static const _key = 'geo_ip_cache_v2';
  static const ttl = Duration(hours: 24);

  Future<Map<String, GeoIpInfo>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return {};
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final result = <String, GeoIpInfo>{};
      decoded.forEach((host, value) {
        if (value is! Map<String, dynamic>) {
          return;
        }
        final time = (value['time'] as num?)?.toInt() ?? 0;
        if (now - time > ttl.inMilliseconds) {
          return;
        }
        final info = GeoIpInfo(
          country: '${value['country'] ?? ''}',
          region: '${value['region'] ?? ''}',
          city: '${value['city'] ?? ''}',
          lat: (value['lat'] as num?)?.toDouble(),
          lon: (value['lon'] as num?)?.toDouble(),
        );
        if (info.hasLocation) {
          result[host] = info;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, GeoIpInfo> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, dynamic>{};
    data.forEach((host, info) {
      if (!info.hasLocation) {
        return;
      }
      encoded[host] = {
        'time': DateTime.now().millisecondsSinceEpoch,
        'country': info.country,
        'region': info.region,
        'city': info.city,
        'lat': info.lat,
        'lon': info.lon,
      };
    });
    await prefs.setString(_key, jsonEncode(encoded));
  }
}
