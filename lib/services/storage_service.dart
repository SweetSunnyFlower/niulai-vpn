import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';

class StorageService {
  static const _subscriptionsKey = 'subscriptions_v1';
  static const _selectedNodeKey = 'selected_node_v1';
  static const _proxyOnlyKey = 'proxy_only_v1';
  static const _builtInSubscriptionsSeededKey =
      'built_in_subscriptions_seeded_v1';
  static const _statusNotificationKey = 'status_notification_v1';
  static const _lastConnectedNodeUrlKey = 'last_connected_node_url_v1';
  static const _proxyAppsEnabledKey = 'proxy_apps_enabled_v1';
  static const _proxyAppsListKey = 'proxy_apps_list_v1';

  Future<List<Subscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_subscriptionsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Subscription.fromJson)
        .whereType<Subscription>()
        .toList();
  }

  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      subscriptions.map((subscription) => subscription.toJson()).toList(),
    );
    await prefs.setString(_subscriptionsKey, encoded);
  }

  Future<String?> loadSelectedNodeUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedNodeKey);
  }

  Future<void> saveSelectedNodeUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(_selectedNodeKey);
    } else {
      await prefs.setString(_selectedNodeKey, url);
    }
  }

  Future<bool> loadProxyOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proxyOnlyKey) ?? false;
  }

  Future<void> saveProxyOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proxyOnlyKey, value);
  }

  Future<bool> loadBuiltInSubscriptionsSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_builtInSubscriptionsSeededKey) ?? false;
  }

  Future<void> saveBuiltInSubscriptionsSeeded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_builtInSubscriptionsSeededKey, value);
  }

  Future<bool> loadStatusNotification() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_statusNotificationKey) ?? true;
  }

  Future<void> saveStatusNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_statusNotificationKey, value);
  }

  Future<String?> loadLastConnectedNodeUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastConnectedNodeUrlKey);
  }

  Future<void> saveLastConnectedNodeUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(_lastConnectedNodeUrlKey);
    } else {
      await prefs.setString(_lastConnectedNodeUrlKey, url);
    }
  }

  Future<bool> loadProxyAppsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proxyAppsEnabledKey) ?? false;
  }

  Future<void> saveProxyAppsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proxyAppsEnabledKey, value);
  }

  Future<List<String>> loadProxyAppsList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_proxyAppsListKey) ?? const [];
  }

  Future<void> saveProxyAppsList(List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_proxyAppsListKey, value);
  }
}
