import 'package:flutter/services.dart';

class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    required this.isSystemApp,
  });

  final String packageName;
  final String label;
  final bool isSystemApp;
}

class InstalledAppsService {
  static const _channel = MethodChannel('app/installed_apps');

  Future<List<InstalledApp>> list() async {
    final result = await _channel.invokeMethod<List<dynamic>>('list');
    return (result ?? const [])
        .whereType<Map>()
        .map(
          (item) => InstalledApp(
            packageName: '${item['packageName'] ?? ''}',
            label: '${item['label'] ?? ''}',
            isSystemApp: item['isSystemApp'] == true,
          ),
        )
        .where((app) => app.packageName.isNotEmpty)
        .toList();
  }

  Future<String> loadIcon(String packageName) async {
    return await _channel.invokeMethod<String>('icon', {
          'packageName': packageName,
        }) ??
        '';
  }
}
