import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../state/app_controller.dart';
import '../widgets/app_ui.dart';
import '../widgets/connect_button.dart';
import '../widgets/gradient_background.dart';
import '../widgets/traffic_chart.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onOpenNodes,
    this.onOpenSettings,
    this.onOpenStats,
  });

  final VoidCallback? onOpenNodes;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenStats;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return GradientBackground(
      child: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.screenTop,
            AppSpacing.page,
            AppSpacing.screenBottom,
          ),
          children: [
            _TopBar(onSettings: onOpenSettings),
            const SizedBox(height: 22),
            _Hero(controller: controller, onOpenNodes: onOpenNodes),
            const SizedBox(height: AppSpacing.section),
            TrafficChart(
              samples: controller.trafficSamples,
              onTap: onOpenStats,
            ),
            const SizedBox(height: AppSpacing.section),
            _ConnectionStats(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.controller, this.onOpenNodes});
  final AppController controller;
  final VoidCallback? onOpenNodes;

  @override
  Widget build(BuildContext context) {
    final connected =
        controller.connectionState == VpnConnectionState.connected;
    final enabled = controller.selectedNode?.isConnectable == true;
    final statusText = connected ? '通道已加密' : '准备好出发了吗？';
    final color = connected ? AppColors.green : AppColors.cyan;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          statusText,
          style: AppTextStyles.body(color: color, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _InlineSpeed(
                  icon: Icons.arrow_upward_rounded,
                  label: '上传',
                  value: Formatters.speed(controller.trafficStatus.uploadSpeed),
                  color: AppColors.cyan,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConnectButton(
              state: controller.connectionState,
              enabled: enabled,
              onPressed: () async {
                final error = connected
                    ? await controller.disconnect()
                    : await controller.connect();
                if (error != null && context.mounted) {
                  await showAppError(context, error);
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _InlineSpeed(
                  icon: Icons.arrow_downward_rounded,
                  label: '下载',
                  value: Formatters.speed(
                    controller.trafficStatus.downloadSpeed,
                  ),
                  color: AppColors.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onOpenNodes,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    enabled
                        ? (controller.selectedNode?.name ?? '未命名节点')
                        : '先选择一个可用节点',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onSettings});

  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '牛来VPN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                '你的安全通道',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSettings,
          tooltip: '设置',
          icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _InlineSpeed extends StatelessWidget {
  const _InlineSpeed({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 4),
              Text(value, style: AppTextStyles.metric()),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption()),
      ],
    );
  }
}

class _ConnectionStats extends StatelessWidget {
  const _ConnectionStats({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final traffic =
        controller.trafficStatus.upload + controller.trafficStatus.download;
    return SurfacePanel(
      padding: const EdgeInsets.all(AppSpacing.card),
      child: Row(
        children: [
          Expanded(
            child: AppMetricTile(
              icon: Icons.swap_vert_rounded,
              label: '流量',
              value: Formatters.traffic(traffic),
              color: AppColors.cyan,
            ),
          ),
          Expanded(
            child: AppMetricTile(
              icon: Icons.timer_outlined,
              label: '连接时长',
              value: controller.trafficStatus.duration,
              color: AppColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}
