import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

import '../config.dart';
import '../models/proxy_node.dart';
import '../models/subscription.dart';
import '../services/latency_service.dart';
import '../services/hysteria2_config_builder.dart';
import '../services/installed_apps_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_parser.dart';
import '../services/subscription_service.dart';
import '../services/traffic_history_store.dart';

enum VpnConnectionState { idle, connecting, connected, disconnecting, error }

class TrafficSample {
  const TrafficSample({
    required this.time,
    required this.uploadSpeed,
    required this.downloadSpeed,
  });

  final DateTime time;
  final int uploadSpeed;
  final int downloadSpeed;
}

class AppController extends ChangeNotifier {
  AppController({
    SubscriptionService? subscriptionService,
    StorageService? storageService,
    LatencyService? latencyService,
    SubscriptionParser? parser,
    TrafficHistoryStore? trafficHistoryStore,
  }) : _subscriptionService = subscriptionService ?? SubscriptionService(),
       _storageService = storageService ?? StorageService(),
       _latencyService = latencyService ?? LatencyService(),
       _parser = parser ?? SubscriptionParser(),
       _trafficHistoryStore = trafficHistoryStore ?? TrafficHistoryStore();

  final SubscriptionService _subscriptionService;
  final StorageService _storageService;
  final LatencyService _latencyService;
  final SubscriptionParser _parser;
  final TrafficHistoryStore _trafficHistoryStore;
  final InstalledAppsService _installedAppsService = InstalledAppsService();

  List<Subscription> subscriptions = [];
  ProxyNode? selectedNode;
  VpnConnectionState connectionState = VpnConnectionState.idle;
  V2RayStatus trafficStatus = V2RayStatus();
  bool loading = true;
  bool busy = false;
  bool proxyOnly = false;
  bool proxyAppsEnabled = false;
  List<String> proxyApps = [];

  FlutterV2ray? _v2ray;
  bool _v2rayInitialized = false;
  final Set<String> _testingNodeIds = <String>{};
  final Set<String> _refreshingSubscriptionIds = <String>{};
  bool statusNotification = true;
  int _lastUploadTotal = 0;
  int _lastDownloadTotal = 0;
  DateTime? _connectionStartedAt;
  final List<TrafficSample> trafficHistory = [
    TrafficSample(
      time: DateTime.now().subtract(const Duration(seconds: 1)),
      uploadSpeed: 0,
      downloadSpeed: 0,
    ),
    TrafficSample(time: DateTime.now(), uploadSpeed: 0, downloadSpeed: 0),
  ];

  static const _maxTrafficSamples = 60;

  List<ProxyNode> get allNodes {
    return subscriptions.expand((subscription) => subscription.nodes).toList();
  }

  bool get hasNodes => allNodes.isNotEmpty;

  List<TrafficSample> get trafficSamples => List.unmodifiable(trafficHistory);

  TrafficHistoryStore get trafficHistoryStore => _trafficHistoryStore;

  Future<void> init() async {
    loading = true;
    notifyListeners();

    try {
      proxyOnly = await _storageService.loadProxyOnly();
      proxyAppsEnabled = await _storageService.loadProxyAppsEnabled();
      proxyApps = await _storageService.loadProxyAppsList();
      statusNotification = await _storageService.loadStatusNotification();
      await _initializeV2Ray();
      subscriptions = await _storageService.loadSubscriptions();
      await _seedBuiltInSubscriptions();

      final selectedUrl = await _storageService.loadSelectedNodeUrl();
      final hasCachedNodes = subscriptions.any(
        (subscription) => subscription.nodes.isNotEmpty,
      );

      if (hasCachedNodes) {
        loading = false;
        _selectBestNode(preferredUrl: selectedUrl);
        notifyListeners();
        unawaited(refreshAllSubscriptions());
      } else {
        await refreshAllSubscriptions(notify: false);
        _selectBestNode(preferredUrl: selectedUrl);
      }
    } catch (_) {
      // Startup failures should not surface globally. Each page reports errors
      // for its own actions.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _seedBuiltInSubscriptions() async {
    final existingUrls = subscriptions.map((item) => item.url).toSet();
    var changed = false;
    for (final url in builtInSubscriptionUrls) {
      if (!existingUrls.contains(url)) {
        subscriptions.add(Subscription(url: url));
        existingUrls.add(url);
        changed = true;
      }
    }

    if (changed) {
      await _storageService.saveSubscriptions(subscriptions);
    }
    await _storageService.saveBuiltInSubscriptionsSeeded(true);
  }

  Future<String?> refreshAllSubscriptions({bool notify = true}) async {
    if (busy) {
      return null;
    }

    busy = true;
    if (notify) {
      notifyListeners();
    }

    String? error;
    try {
      error = await _refreshAllSubscriptions().timeout(
        const Duration(seconds: 25),
      );
    } on TimeoutException {
      error = '刷新超时，已取消等待';
    } finally {
      busy = false;
      if (notify) {
        notifyListeners();
      }
    }
    return error;
  }

  Future<String?> _refreshAllSubscriptions() async {
    String? firstError;
    for (final subscription in List<Subscription>.from(subscriptions)) {
      final error = await refreshSubscription(subscription);
      firstError ??= error;
    }
    return firstError;
  }

  Future<String?> refreshSubscription(
    Subscription subscription, {
    bool notify = true,
  }) async {
    _refreshingSubscriptionIds.add(subscription.id);
    if (notify) {
      notifyListeners();
    }

    try {
      final body = await _subscriptionService.fetch(subscription.url);
      final nodes = _parseNodes(body);
      subscription.nodes = nodes;
      subscription.lastUpdated = DateTime.now();
      if (subscription.name.trim().isEmpty) {
        subscription.name = Uri.tryParse(subscription.url)?.host ?? '订阅';
      }
      await _storageService.saveSubscriptions(subscriptions);
      return null;
    } catch (error) {
      return '刷新订阅 ${subscription.displayName} 失败：${_friendlyError(error)}';
    } finally {
      _refreshingSubscriptionIds.remove(subscription.id);
      if (notify) {
        notifyListeners();
      }
    }
  }

  /// Adds a subscription without fetching it.
  ///
  /// Returns the created subscription on success, or a user-facing error.
  Future<({String? error, Subscription? subscription})> addSubscription(
    String url,
  ) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return (error: '请输入订阅链接', subscription: null);
    }
    if (subscriptions.any((subscription) => subscription.url == trimmed)) {
      return (error: '该订阅已存在', subscription: null);
    }

    final subscription = Subscription(url: trimmed);
    subscriptions.add(subscription);
    await _storageService.saveSubscriptions(subscriptions);
    notifyListeners();
    return (error: null, subscription: subscription);
  }

  Future<void> removeSubscription(Subscription subscription) async {
    subscriptions.removeWhere((item) => item.id == subscription.id);

    if (selectedNode != null &&
        !subscriptions.any(
          (item) => item.nodes.any((node) => node.id == selectedNode!.id),
        )) {
      selectedNode = null;
      await _storageService.saveSelectedNodeUrl(null);
      _selectBestNode();
    }

    await _storageService.saveSubscriptions(subscriptions);
    notifyListeners();
  }

  /// Returns null on success, otherwise a user-facing error message.
  Future<String?> updateSubscription({
    required Subscription subscription,
    required String name,
    required String url,
  }) async {
    final trimmedUrl = url.trim();
    final trimmedName = name.trim();
    if (trimmedUrl.isEmpty) {
      return '订阅链接不能为空';
    }

    final urlChanged = trimmedUrl != subscription.url;
    if (urlChanged &&
        subscriptions.any(
          (item) => item.id != subscription.id && item.url == trimmedUrl,
        )) {
      return '该订阅链接已存在';
    }

    final index = subscriptions.indexWhere(
      (item) => item.id == subscription.id,
    );
    if (index == -1) {
      return '订阅不存在';
    }

    final updated = urlChanged
        ? Subscription(url: trimmedUrl, name: trimmedName)
        : Subscription(
            url: subscription.url,
            name: trimmedName,
            lastUpdated: subscription.lastUpdated,
            nodes: subscription.nodes,
          );
    subscriptions[index] = updated;
    await _storageService.saveSubscriptions(subscriptions);
    notifyListeners();

    final refreshError = urlChanged ? await refreshSubscription(updated) : null;

    if (selectedNode != null &&
        !subscriptions.any(
          (item) => item.nodes.any((node) => node.id == selectedNode!.id),
        )) {
      _selectBestNode();
    }

    return refreshError;
  }

  Future<String?> selectNode(ProxyNode node) async {
    if (node.id == selectedNode?.id) {
      return null;
    }

    selectedNode = node;
    await _storageService.saveSelectedNodeUrl(node.url);
    notifyListeners();

    if (connectionState == VpnConnectionState.connected ||
        connectionState == VpnConnectionState.connecting) {
      final disconnectError = await disconnect();
      if (disconnectError != null) {
        return disconnectError;
      }
      return connect();
    }

    return null;
  }

  Future<void> setProxyOnly(bool value) async {
    proxyOnly = value;
    await _storageService.saveProxyOnly(value);
    notifyListeners();
  }

  Future<void> setProxyAppsEnabled(bool value) async {
    proxyAppsEnabled = value;
    await _storageService.saveProxyAppsEnabled(value);
    notifyListeners();
    unawaited(_restartVpnIfNeeded());
  }

  Future<void> setProxyApps(List<String> value) async {
    proxyApps = value;
    await _storageService.saveProxyAppsList(value);
    notifyListeners();
    unawaited(_restartVpnIfNeeded());
  }

  Future<void> _restartVpnIfNeeded() async {
    if (connectionState != VpnConnectionState.connected &&
        connectionState != VpnConnectionState.connecting) {
      return;
    }
    await disconnect();
    if (selectedNode?.isConnectable == true) {
      await connect();
    }
  }

  Future<void> setStatusNotification(bool value) async {
    statusNotification = value;
    await _storageService.saveStatusNotification(value);
    notifyListeners();
  }

  Future<void> testLatency(ProxyNode node) async {
    if (_testingNodeIds.contains(node.id)) {
      return;
    }

    _testingNodeIds.add(node.id);
    notifyListeners();

    try {
      final port = node.port ?? 443;
      final latency = await _latencyService.ping(node.address, port);
      _replaceNode(node.withLatency(latency ?? -1));
    } finally {
      _testingNodeIds.remove(node.id);
      notifyListeners();
    }
  }

  bool isTestingNode(String nodeId) => _testingNodeIds.contains(nodeId);

  bool isRefreshingSubscription(String subscriptionId) =>
      _refreshingSubscriptionIds.contains(subscriptionId);

  Future<String?> connect() async {
    final node = selectedNode;
    if (node == null) {
      return '请先选择节点';
    }
    if (!node.isConnectable) {
      return '${node.protocol.label} 协议暂不支持连接';
    }
    if (connectionState == VpnConnectionState.connected ||
        connectionState == VpnConnectionState.connecting) {
      return null;
    }

    await _storageService.saveLastConnectedNodeUrl(node.url);
    connectionState = VpnConnectionState.connecting;
    _lastUploadTotal = 0;
    _lastDownloadTotal = 0;
    _connectionStartedAt = null;
    notifyListeners();

    String? error;
    try {
      await _initializeV2Ray();
      if (!_v2rayInitialized) {
        throw Exception('VPN 引擎不可用');
      }

      if (!proxyOnly) {
        final granted = await _v2ray!.requestPermission();
        if (!granted) {
          throw Exception('未授予 VPN 权限');
        }
      }

      final config = node.protocol == ProxyProtocol.hysteria2
          ? Hysteria2ConfigBuilder.build(node)
          : FlutterV2ray.parseFromURL(node.url).getFullConfiguration();
      List<String>? blockedApps;
      if (proxyAppsEnabled) {
        final installedApps = await _installedAppsService.list();
        final selected = proxyApps.toSet();
        blockedApps = installedApps
            .map((app) => app.packageName)
            .where((packageName) => !selected.contains(packageName))
            .toList();
      }
      await _v2ray!.startV2Ray(
        remark: node.name,
        config: config,
        proxyOnly: proxyOnly,
        blockedApps: blockedApps,
        notificationDisconnectButtonName: '断开连接',
      );
    } catch (caught) {
      connectionState = VpnConnectionState.idle;
      error = _friendlyError(caught);
    }

    notifyListeners();
    return error;
  }

  Future<void> _initializeV2Ray() async {
    if (_v2rayInitialized) {
      return;
    }

    _v2ray ??= FlutterV2ray(onStatusChanged: _handleStatus);
    try {
      await _v2ray!.initializeV2Ray(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );
      _v2rayInitialized = true;
    } catch (_) {
      // The VPN engine may not be available on this platform. Connection
      // initialization will be retried when the user taps connect.
    }
  }

  Future<String?> disconnect() async {
    if (connectionState == VpnConnectionState.idle ||
        connectionState == VpnConnectionState.disconnecting) {
      return null;
    }

    connectionState = VpnConnectionState.disconnecting;
    notifyListeners();

    String? error;
    try {
      await _v2ray?.stopV2Ray();
    } catch (caught) {
      error = _friendlyError(caught);
    }

    await _finalizeTrafficSession(DateTime.now());
    connectionState = VpnConnectionState.idle;
    trafficStatus = V2RayStatus();
    notifyListeners();
    return error;
  }

  Future<void> _finalizeTrafficSession(DateTime now) async {
    final start = _connectionStartedAt;
    if (start != null) {
      await _trafficHistoryStore.addDuration(start: start, end: now);
    }
    _connectionStartedAt = null;
    _lastUploadTotal = 0;
    _lastDownloadTotal = 0;
    await _trafficHistoryStore.pruneBefore(
      now.subtract(const Duration(days: 30)),
    );
  }

  void _handleStatus(V2RayStatus status) {
    trafficStatus = status;
    final state = status.state.toUpperCase();
    final now = DateTime.now();

    final uploadDelta = status.upload >= _lastUploadTotal
        ? status.upload - _lastUploadTotal
        : 0;
    final downloadDelta = status.download >= _lastDownloadTotal
        ? status.download - _lastDownloadTotal
        : 0;
    _lastUploadTotal = status.upload;
    _lastDownloadTotal = status.download;

    if (state == 'CONNECTED' && _connectionStartedAt == null) {
      _connectionStartedAt = now;
    }

    if (uploadDelta > 0 || downloadDelta > 0) {
      unawaited(
        _trafficHistoryStore.addTraffic(
          time: now,
          uploadBytes: uploadDelta,
          downloadBytes: downloadDelta,
        ),
      );
    }

    trafficHistory.add(
      TrafficSample(
        time: now,
        uploadSpeed: status.uploadSpeed,
        downloadSpeed: status.downloadSpeed,
      ),
    );
    if (trafficHistory.length > _maxTrafficSamples) {
      trafficHistory.removeAt(0);
    }
    switch (state) {
      case 'CONNECTING':
        connectionState = VpnConnectionState.connecting;
      case 'CONNECTED':
        connectionState = VpnConnectionState.connected;
      case 'DISCONNECTED':
        connectionState = VpnConnectionState.idle;
        trafficStatus = V2RayStatus();
        unawaited(_finalizeTrafficSession(now));
      default:
        break;
    }
    notifyListeners();
  }

  List<ProxyNode> _parseNodes(String body) {
    return _parser.parse(body);
  }

  void _selectBestNode({String? preferredUrl}) {
    final nodes = allNodes;
    final preferred = _findNode(preferredUrl);
    selectedNode = preferred ?? (nodes.isNotEmpty ? nodes.first : null);
    if (selectedNode != null) {
      unawaited(_storageService.saveSelectedNodeUrl(selectedNode!.url));
    }
  }

  ProxyNode? _findNode(String? url) {
    if (url == null) {
      return null;
    }
    for (final subscription in subscriptions) {
      for (final node in subscription.nodes) {
        if (node.id == url) {
          return node;
        }
      }
    }
    return null;
  }

  void _replaceNode(ProxyNode updated) {
    _replaceNodeSilent(updated);
    notifyListeners();
  }

  void _replaceNodeSilent(ProxyNode updated) {
    for (final subscription in subscriptions) {
      final index = subscription.nodes.indexWhere(
        (node) => node.id == updated.id,
      );
      if (index != -1) {
        subscription.nodes[index] = updated;
      }
    }
    if (selectedNode?.id == updated.id) {
      selectedNode = updated;
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('MissingPluginException')) {
      return '当前平台不支持 VPN 引擎';
    }
    if (text.contains('SocketException')) {
      return '网络错误，请检查网络后重试';
    }
    return text.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    if (connectionState == VpnConnectionState.connected) {
      unawaited(_v2ray?.stopV2Ray());
    }
    super.dispose();
  }
}
