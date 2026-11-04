import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/proxy_node.dart';
import '../services/geo_ip_cache_store.dart';
import '../services/geo_ip_service.dart';
import '../state/app_controller.dart';
import '../widgets/app_ui.dart';
import '../widgets/gradient_background.dart';
import '../widgets/world_map.dart';

class NodeMapScreen extends StatefulWidget {
  const NodeMapScreen({super.key});

  @override
  State<NodeMapScreen> createState() => _NodeMapScreenState();
}

class _NodeMapScreenState extends State<NodeMapScreen> {
  final GeoIpService _geoIpService = GeoIpService();
  final GeoIpCacheStore _geoIpCacheStore = GeoIpCacheStore();
  final Map<String, GeoIpInfo> _geoInfo = {};
  final Set<String> _loadingAddresses = {};
  final TransformationController _mapTransform = TransformationController();

  WorldMapGeometry? _geometry;
  Object? _geometryError;
  bool _started = false;
  bool _mapTransformInitialized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGeometry());
  }

  @override
  void dispose() {
    _mapTransform.dispose();
    super.dispose();
  }

  Future<void> _loadGeometry() async {
    try {
      final source = await rootBundle.loadString(
        'assets/geojson/world_countries.geojson',
      );
      final geometry = WorldMapGeometry.parse(source);
      if (!mounted) {
        return;
      }
      setState(() => _geometry = geometry);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _geometryError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final nodes = controller.allNodes
        .where((node) => node.isConnectable)
        .toList();
    final selectedNode = controller.selectedNode;

    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadGeo(nodes));
        }
      });
    }

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '节点分布',
              subtitle: '${nodes.length} 个可用节点 · 可双指缩放与拖动',
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: '返回',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(child: _buildBody(nodes, selectedNode)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<ProxyNode> nodes, ProxyNode? selectedNode) {
    if (_geometryError != null) {
      return const AppEmptyState(
        icon: Icons.public_off_rounded,
        title: '地图加载失败',
        message: '无法读取内置世界地图数据',
      );
    }
    if (_geometry == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.cyan),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final mapSize = WorldMapProjection.fullHeight(viewport);
        final markers = <Widget>[];
        final groups = _buildCityGroups(nodes);
        _ensureMapTransform(viewport, mapSize);

        for (final group in groups) {
          final position = WorldMapProjection.project(
            lat: group.lat,
            lon: group.lon,
            size: mapSize,
          );
          final selected = group.nodes.any(
            (node) => node.id == selectedNode?.id,
          );
          const markerWidth = 92.0;
          markers.add(
            Positioned(
              left: position.dx - markerWidth / 2,
              top: position.dy - (selected ? 7 : 5),
              child: _FixedScaleMarker(
                controller: _mapTransform,
                child: _CityMarker(
                  city: group.cityLabel,
                  selected: selected,
                  onTap: () => _showCityDetails(context, group),
                ),
              ),
            ),
          );
        }

        return InteractiveViewer(
          transformationController: _mapTransform,
          constrained: false,
          minScale: 1,
          maxScale: 32,
          boundaryMargin: EdgeInsets.zero,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: mapSize.width,
            height: mapSize.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: WorldMapPainter(
                      geometry: _geometry!,
                      landColor: AppColors.surfaceLight.withValues(alpha: 0.66),
                      borderColor: AppColors.cyan.withValues(alpha: 0.34),
                    ),
                  ),
                ),
                ...markers,
              ],
            ),
          ),
        );
      },
    );
  }

  void _ensureMapTransform(Size viewport, Size mapSize) {
    if (_mapTransformInitialized) {
      return;
    }
    _mapTransformInitialized = true;
    final dx = -(mapSize.width - viewport.width) / 2;
    _mapTransform.value = Matrix4.translationValues(dx, 0.0, 0.0);
  }

  Future<void> _loadGeo(List<ProxyNode> nodes) async {
    final cached = await _geoIpCacheStore.load();
    if (!mounted) {
      return;
    }
    setState(() => _geoInfo.addAll(cached));

    final missing = nodes
        .where((node) => !_geoInfo.containsKey(node.address))
        .toList();
    if (missing.isEmpty) {
      return;
    }

    setState(() {
      _loadingAddresses.addAll(missing.map((node) => node.address));
    });

    const batchSize = 5;
    for (var start = 0; start < missing.length; start += batchSize) {
      final batch = missing.skip(start).take(batchSize).toList();
      await Future.wait(
        batch.map((node) async {
          final info = await _geoIpService.fetch(node.address);
          if (!mounted) {
            return;
          }
          setState(() {
            _loadingAddresses.remove(node.address);
            if (info != null) {
              _geoInfo[node.address] = info;
            }
          });
        }),
      );
    }

    await _geoIpCacheStore.save(_geoInfo);
  }

  List<_CityNodeGroup> _buildCityGroups(List<ProxyNode> nodes) {
    final grouped = <String, List<ProxyNode>>{};
    for (final node in nodes) {
      final geo = _geoInfo[node.address];
      if (geo == null || geo.lat == null || geo.lon == null) {
        continue;
      }
      final key = _groupKey(geo);
      grouped.putIfAbsent(key, () => []).add(node);
    }

    final groups = <_CityNodeGroup>[];
    grouped.forEach((key, groupNodes) {
      var latSum = 0.0;
      var lonSum = 0.0;
      var coordinateCount = 0;
      GeoIpInfo? firstGeo;

      for (final node in groupNodes) {
        final geo = _geoInfo[node.address];
        if (geo == null || geo.lat == null || geo.lon == null) {
          continue;
        }
        firstGeo ??= geo;
        latSum += geo.lat!;
        lonSum += geo.lon!;
        coordinateCount++;
      }

      if (coordinateCount == 0 || firstGeo == null) {
        return;
      }

      groups.add(
        _CityNodeGroup(
          cityLabel: _cityLabel(firstGeo),
          location: _locationLabel(firstGeo),
          nodes: groupNodes,
          lat: latSum / coordinateCount,
          lon: lonSum / coordinateCount,
        ),
      );
    });

    groups.sort((a, b) => a.cityLabel.compareTo(b.cityLabel));
    return groups;
  }

  String _groupKey(GeoIpInfo geo) {
    final parts = [
      geo.country,
      geo.region,
      geo.city,
    ].where((value) => value.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      return parts.join('|');
    }
    return '${geo.lat},${geo.lon}';
  }

  String _cityLabel(GeoIpInfo geo) {
    if (geo.city.isNotEmpty) {
      return geo.city;
    }
    if (geo.region.isNotEmpty) {
      return geo.region;
    }
    return geo.country.isEmpty ? '未知位置' : geo.country;
  }

  String _locationLabel(GeoIpInfo geo) {
    final location = [
      geo.country,
      geo.region,
      geo.city,
    ].where((value) => value.isNotEmpty).join(' · ');
    return location.isEmpty ? '未知位置' : location;
  }

  Future<void> _showCityDetails(
    BuildContext context,
    _CityNodeGroup group,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _CityNodesSheet(group: group),
    );
  }
}

class _CityNodeGroup {
  const _CityNodeGroup({
    required this.cityLabel,
    required this.location,
    required this.nodes,
    required this.lat,
    required this.lon,
  });

  final String cityLabel;
  final String location;
  final List<ProxyNode> nodes;
  final double lat;
  final double lon;
}

class _CityMarker extends StatelessWidget {
  const _CityMarker({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final String city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.cyan;
    final dotSize = selected ? 14.0 : 10.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 92,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.9),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: selected ? 0.55 : 0.30),
                    blurRadius: selected ? 12 : 7,
                    spreadRadius: selected ? 2 : 0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(
                color: selected ? AppColors.green : AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedScaleMarker extends StatelessWidget {
  const _FixedScaleMarker({required this.controller, required this.child});

  final TransformationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scale = controller.value.getMaxScaleOnAxis();
        return Transform.scale(scale: 1 / scale, child: child);
      },
    );
  }
}

class _CityNodesSheet extends StatefulWidget {
  const _CityNodesSheet({required this.group});

  final _CityNodeGroup group;

  @override
  State<_CityNodesSheet> createState() => _CityNodesSheetState();
}

class _CityNodesSheetState extends State<_CityNodesSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final controller = context.read<AppController>();
      for (final node in widget.group.nodes) {
        if (!controller.isTestingNode(node.id)) {
          unawaited(controller.testLatency(node));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.card,
            AppSpacing.card,
            AppSpacing.card,
            AppSpacing.screenBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.group.cityLabel,
                      style: AppTextStyles.screenTitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${widget.group.nodes.length} 个节点',
                    style: AppTextStyles.secondary(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.group.location,
                style: AppTextStyles.secondary(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.group.nodes.length,
                  itemBuilder: (context, index) {
                    final node = widget.group.nodes[index];
                    final current = controller.allNodes.firstWhere(
                      (item) => item.id == node.id,
                      orElse: () => node,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CityNodeRow(
                        node: current,
                        testing: controller.isTestingNode(current.id),
                        onConnect: () => _connectNode(context, current),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectNode(BuildContext sheetContext, ProxyNode node) async {
    final controller = context.read<AppController>();
    final selectError = await controller.selectNode(node);
    if (selectError != null) {
      if (sheetContext.mounted) {
        await showAppError(sheetContext, selectError);
      }
      return;
    }

    final connectError = await controller.connect();
    if (connectError != null) {
      if (sheetContext.mounted) {
        await showAppError(sheetContext, connectError);
      }
      return;
    }

    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
  }
}

class _CityNodeRow extends StatelessWidget {
  const _CityNodeRow({
    required this.node,
    required this.testing,
    required this.onConnect,
  });

  final ProxyNode node;
  final bool testing;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final latency = node.latencyMs;
    final latencyLabel = testing
        ? '测速中...'
        : latency == null
        ? '延迟 --'
        : latency < 0
        ? '超时'
        : Formatters.latency(latency);
    final latencyColor = testing
        ? AppColors.cyan
        : latency != null && latency < 0
        ? AppColors.red
        : AppColors.textSecondary;

    return SurfacePanel(
      borderRadius: AppRadii.control,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
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
                  latencyLabel,
                  style: AppTextStyles.caption(
                    color: latencyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onConnect, child: const Text('连接')),
        ],
      ),
    );
  }
}
