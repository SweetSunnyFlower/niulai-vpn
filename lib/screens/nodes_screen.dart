import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/proxy_node.dart';
import '../services/geo_ip_cache_store.dart';
import '../services/geo_ip_service.dart';
import '../state/app_controller.dart';
import '../widgets/app_ui.dart';
import '../widgets/gradient_background.dart';

class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key, this.onBack, this.initialSubscriptionId});

  final VoidCallback? onBack;
  final String? initialSubscriptionId;

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  static const _allTabKey = '__all__';

  final GeoIpService _geoIpService = GeoIpService();
  final GeoIpCacheStore _geoIpCacheStore = GeoIpCacheStore();
  final Map<String, GeoIpInfo> _geoInfo = {};
  final Set<String> _geoLoading = {};
  final Set<String> _requestedGeoHosts = {};
  bool _cacheLoaded = false;
  final GlobalKey _tabStripKey = GlobalKey();
  String? _selectedSubscriptionId;
  double? _tabIndicatorLeft;
  double? _tabIndicatorWidth;
  bool _tabBarInitialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _selectedSubscriptionId = widget.initialSubscriptionId;
    unawaited(_ensureCacheLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final tabs = _buildTabs(controller);
    final allNodes = controller.allNodes;
    final selected = controller.selectedNode;
    final connectable = allNodes.where((node) => node.isConnectable).toList();
    final nodes = _selectedSubscriptionId == null
        ? connectable
        : controller.subscriptions
              .where(
                (subscription) => subscription.id == _selectedSubscriptionId,
              )
              .expand((subscription) => subscription.nodes)
              .where((node) => node.isConnectable)
              .toList();
    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '节点浏览器',
              titleWidget: SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.screenTitle(),
                    children: [
                      const TextSpan(text: '节点浏览器'),
                      if (selected != null)
                        TextSpan(
                          text: ' · ${selected.name}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              leading: IconButton(
                onPressed:
                    widget.onBack ?? () => Navigator.of(context).maybePop(),
                tooltip: '返回',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).pushNamed('/node-map'),
                  tooltip: '节点分布',
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.public_rounded),
                ),
              ],
            ),
            _buildSubscriptionTabBar(tabs),
            const SizedBox(height: AppSpacing.dense),
            Expanded(
              child: nodes.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.dns_outlined,
                      title: '未找到节点',
                      message: '暂时没有可用节点',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.screenBottom,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.dense,
                            crossAxisSpacing: AppSpacing.dense,
                            childAspectRatio: 1.2,
                          ),
                      itemCount: nodes.length,
                      itemBuilder: (context, index) {
                        final node = nodes[index];
                        _requestGeoForNode(node);
                        return _NodeGridCard(
                          node: node,
                          selected: selected?.id == node.id,
                          testing: controller.isTestingNode(node.id),
                          geoInfo: _geoInfo[node.address],
                          geoLoading: _geoLoading.contains(node.address),
                          onTap: () => _selectNode(context, node),
                          onLatencyTap: () =>
                              unawaited(controller.testLatency(node)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectNode(BuildContext context, ProxyNode node) async {
    final error = await context.read<AppController>().selectNode(node);
    if (error == null || !context.mounted) {
      return;
    }
    await showAppError(context, error);
  }

  Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) {
      return;
    }
    _cacheLoaded = true;
    final cached = await _geoIpCacheStore.load();
    cached.removeWhere((_, info) => !info.hasLocation);
    if (!mounted) {
      return;
    }
    setState(() {
      _geoInfo.addAll(cached);
    });
  }

  void _requestGeoForNode(ProxyNode node) {
    if (_requestedGeoHosts.contains(node.address)) {
      return;
    }
    _requestedGeoHosts.add(node.address);
    unawaited(_loadGeoForNode(node));
  }

  Future<void> _loadGeoForNode(ProxyNode node) async {
    await _ensureCacheLoaded();
    if (!mounted || _geoInfo.containsKey(node.address)) {
      return;
    }

    setState(() => _geoLoading.add(node.address));
    final info = await _geoIpService.fetch(node.address);
    if (!mounted) {
      return;
    }
    setState(() {
      _geoLoading.remove(node.address);
      if (info != null) {
        _geoInfo[node.address] = info;
      }
    });
    await _geoIpCacheStore.save(_geoInfo);
  }

  List<_SubscriptionTabData> _buildTabs(AppController controller) {
    final allNodes = controller.allNodes;
    final tabs = [
      _SubscriptionTabData(
        id: null,
        label: '全部',
        total: allNodes.length,
        available: allNodes.where((node) => node.isConnectable).length,
      ),
    ];
    for (final subscription in controller.subscriptions) {
      final nodes = subscription.nodes;
      tabs.add(
        _SubscriptionTabData(
          id: subscription.id,
          label: subscription.displayName,
          total: nodes.length,
          available: nodes.where((node) => node.isConnectable).length,
        ),
      );
    }
    return tabs;
  }

  Widget _buildSubscriptionTabBar(List<_SubscriptionTabData> tabs) {
    if (!_tabBarInitialScrollDone) {
      _tabBarInitialScrollDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateTabIndicator();
          _ensureSelectedTabVisible();
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: SingleChildScrollView(
        key: const PageStorageKey('node-subscription-tabs'),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Stack(
          key: _tabStripKey,
          clipBehavior: Clip.none,
          children: [
            Row(children: [for (final tab in tabs) _buildSubscriptionTab(tab)]),
            if (_tabIndicatorLeft != null && _tabIndicatorWidth != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: _tabIndicatorLeft!,
                bottom: 0,
                child: Container(
                  height: 2,
                  width: _tabIndicatorWidth,
                  decoration: BoxDecoration(
                    color: AppColors.cyan,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionTab(_SubscriptionTabData tab) {
    final keyName = tab.id ?? _allTabKey;
    final selected = tab.id == _selectedSubscriptionId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        key: GlobalObjectKey(keyName),
        onTap: () {
          setState(() => _selectedSubscriptionId = tab.id);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateTabIndicator();
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  color: selected ? AppColors.cyan : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  void _updateTabIndicator() {
    final keyName = _selectedSubscriptionId ?? _allTabKey;
    final tabContext = GlobalObjectKey(keyName).currentContext;
    final stripContext = _tabStripKey.currentContext;
    if (tabContext == null || stripContext == null) {
      return;
    }
    final tabBox = tabContext.findRenderObject() as RenderBox?;
    final stripBox = stripContext.findRenderObject() as RenderBox?;
    if (tabBox == null || stripBox == null || !mounted) {
      return;
    }
    final offset = tabBox.localToGlobal(Offset.zero, ancestor: stripBox);
    final width = tabBox.size.width > 8 ? tabBox.size.width - 8 : 0.0;
    setState(() {
      _tabIndicatorLeft = offset.dx + 4;
      _tabIndicatorWidth = width;
    });
  }

  void _ensureSelectedTabVisible() {
    final keyName = _selectedSubscriptionId ?? _allTabKey;
    final tabContext = GlobalObjectKey(keyName).currentContext;
    if (tabContext == null) {
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        tabContext,
        duration: const Duration(milliseconds: 240),
        alignment: 0.5,
        curve: Curves.easeOut,
      ),
    );
  }
}

class _SubscriptionTabData {
  const _SubscriptionTabData({
    required this.id,
    required this.label,
    required this.total,
    required this.available,
  });

  final String? id;
  final String label;
  final int total;
  final int available;
}

class _NodeGridCard extends StatelessWidget {
  const _NodeGridCard({
    required this.node,
    required this.selected,
    required this.testing,
    required this.geoInfo,
    required this.geoLoading,
    required this.onTap,
    required this.onLatencyTap,
  });

  final ProxyNode node;
  final bool selected;
  final bool testing;
  final GeoIpInfo? geoInfo;
  final bool geoLoading;
  final VoidCallback onTap;
  final VoidCallback onLatencyTap;

  @override
  Widget build(BuildContext context) {
    final latency = node.latencyMs;
    final latencyLabel = testing
        ? '测速中'
        : latency == null
        ? '未测速'
        : latency < 0
        ? '超时'
        : Formatters.latency(latency);

    return SurfacePanel(
      onTap: onTap,
      borderRadius: AppRadii.control,
      border: selected ? Border.all(color: AppColors.cyan, width: 1) : null,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            node.endpoint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.secondary(),
          ),
          const SizedBox(height: 4),
          Text(
            '${node.protocol.label} · ${node.isConnectable ? '可连接' : '暂不支持'}',
            style: AppTextStyles.caption(),
          ),
          const SizedBox(height: 4),
          Text(
            geoLoading
                ? '归属地查询中...'
                : geoInfo == null
                ? '归属地未知'
                : '${geoInfo!.country} · ${geoInfo!.region} · ${geoInfo!.city}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                latencyLabel,
                style: AppTextStyles.secondary(
                  color: testing ? AppColors.cyan : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: latency == null ? '测试端口延迟' : '重新测速',
                onPressed: testing ? null : onLatencyTap,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.speed_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
