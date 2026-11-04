import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/proxy_node.dart';
import '../services/geo_ip_service.dart';
import 'app_ui.dart';

class NodeCard extends StatelessWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.selected,
    required this.onTap,
    this.onLatencyTap,
    this.showLatencyAction = false,
    this.testing = false,
    this.geoInfo,
    this.geoLoading = false,
  });

  final ProxyNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLatencyTap;
  final bool showLatencyAction;
  final bool testing;
  final GeoIpInfo? geoInfo;
  final bool geoLoading;

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
    final canTest = showLatencyAction && onLatencyTap != null;

    return Semantics(
      selected: selected,
      child: SurfacePanel(
        onTap: onTap,
        borderRadius: AppRadii.control,
        border: selected
            ? Border(right: BorderSide(color: AppColors.cyan, width: 3))
            : null,
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
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
                    '${node.protocol.label} · ${node.isConnectable ? '可连接' : '暂不支持连接'}',
                    style: AppTextStyles.caption(
                      color: node.isConnectable
                          ? AppColors.textSecondary
                          : AppColors.amber,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    geoLoading
                        ? '归属地查询中...'
                        : geoInfo == null
                        ? '归属地未知'
                        : '${geoInfo!.country} · ${geoInfo!.region} · ${geoInfo!.city}',
                    style: AppTextStyles.caption(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  latencyLabel,
                  style: AppTextStyles.secondary(
                    color: testing ? AppColors.cyan : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (testing)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (canTest)
                  IconButton(
                    tooltip: latency == null ? '测试端口延迟' : '重新测速',
                    onPressed: onLatencyTap,
                    icon: const Icon(Icons.speed_rounded, size: 20),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
