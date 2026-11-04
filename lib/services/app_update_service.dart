import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.forceUpdate,
    required this.downloadUrl,
    this.releaseNotes,
  });

  final String version;
  final bool forceUpdate;
  final String downloadUrl;
  final String? releaseNotes;

  static AppUpdateInfo? fromJson(Map<String, dynamic> json) {
    final version = '${json['version'] ?? ''}'.trim();
    final downloadUrl = '${json['download_url'] ?? ''}'.trim();
    if (version.isEmpty || downloadUrl.isEmpty) {
      return null;
    }

    final notes = json['release_notes'];
    return AppUpdateInfo(
      version: version,
      forceUpdate: json['force_update'] == true || json['force'] == true,
      downloadUrl: downloadUrl,
      releaseNotes: notes is String && notes.isNotEmpty ? notes : null,
    );
  }
}

class AppUpdateService {
  AppUpdateService({String? endpoint})
    : endpoint = endpoint ?? appUpdateEndpoint;

  final String endpoint;

  Future<AppUpdateInfo?> fetchLatest() async {
    try {
      final uri = Uri.parse(endpoint);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return AppUpdateInfo.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
