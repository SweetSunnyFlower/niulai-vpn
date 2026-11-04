import 'dart:convert';

import 'package:http/http.dart' as http;

class GeoIpInfo {
  const GeoIpInfo({
    required this.country,
    required this.region,
    required this.city,
    this.lat,
    this.lon,
  });

  final String country;
  final String region;
  final String city;
  final double? lat;
  final double? lon;

  bool get hasLocation =>
      country.isNotEmpty || region.isNotEmpty || city.isNotEmpty;
}

class GeoIpService {
  static GeoIpInfo? parseResponse(Map<String, dynamic> json) {
    if (json['status'] != 'success') {
      return null;
    }
    final country = '${json['country'] ?? ''}';
    final region = '${json['regionName'] ?? ''}';
    final city = '${json['city'] ?? ''}';
    if (country.isEmpty && region.isEmpty && city.isEmpty) {
      return null;
    }
    return GeoIpInfo(
      country: country,
      region: region,
      city: city,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }

  Future<GeoIpInfo?> fetch(String host) async {
    if (host.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse('http://ip-api.com/json/$host?lang=zh-CN');
      final response = await http.get(uri).timeout(const Duration(minutes: 1));
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return parseResponse(decoded);
    } catch (_) {
      return null;
    }
  }
}
