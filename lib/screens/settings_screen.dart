import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../core/app_theme.dart';
import '../core/version_utils.dart';
import '../services/app_update_downloader.dart';
import '../services/app_update_service.dart';
import '../state/app_controller.dart';
import '../widgets/app_ui.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/gradient_background.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.onOpenNodes, this.onOpenSubscriptions});

  final VoidCallback? onOpenNodes;
  final VoidCallback? onOpenSubscriptions;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return GradientBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppSpacing.screenTop,
            0,
            AppSpacing.screenBottom,
          ),
          children: [
            AppPageHeader(
              title: '设置',
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                children: [
                  const AppSectionHeader(title: '功能'),
                  const SizedBox(height: AppSpacing.dense),
                  SurfacePanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.rss_feed_outlined),
                          title: const Text('订阅数据源'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: onOpenSubscriptions,
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.dns_outlined),
                          title: const Text('全部节点'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: onOpenNodes,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  const AppSectionHeader(title: '连接行为'),
                  const SizedBox(height: AppSpacing.dense),
                  SurfacePanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        _CompactSwitchTile(
                          value: controller.statusNotification,
                          onChanged: controller.setStatusNotification,
                          title: const Text('状态通知'),
                          subtitle: const Text('连接期间显示节点名和断开按钮'),
                        ),
                        const Divider(),
                        _CompactSwitchTile(
                          value: controller.proxyAppsEnabled,
                          onChanged: controller.setProxyAppsEnabled,
                          title: const Text('指定 APP 走 VPN'),
                          subtitle: const Text('开启后仅勾选的 APP 走 VPN'),
                        ),
                        if (controller.proxyAppsEnabled) ...[
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.apps_rounded),
                            title: const Text('VPN APP'),
                            subtitle: Text(
                              '已选择 ${controller.proxyApps.length} 个',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                Navigator.of(context).pushNamed('/proxy-apps'),
                          ),
                        ],
                        const Divider(),
                        const _AppInfoTile(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppInfoTile extends StatefulWidget {
  const _AppInfoTile();

  @override
  State<_AppInfoTile> createState() => _AppInfoTileState();
}

class _AppInfoTileState extends State<_AppInfoTile> {
  final AppUpdateService _updateService = AppUpdateService();
  String _version = '';
  bool _checkingUpdate = true;
  bool _updateAvailable = false;
  AppUpdateInfo? _latestInfo;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _version = 'v${info.version}';
    });
    await _loadUpdateState();
  }

  Future<void> _loadUpdateState() async {
    final info = await _updateService.fetchLatest();
    if (!mounted) {
      return;
    }
    setState(() {
      _checkingUpdate = false;
      _updateAvailable =
          info != null &&
          _version.isNotEmpty &&
          VersionUtils.isNewer(info.version, _version);
      _latestInfo = _updateAvailable ? info : null;
    });
  }

  Future<void> _openUpdate() async {
    final info = _latestInfo;
    if (info == null || !mounted) {
      return;
    }
    await showAppUpdateDialog(
      context: context,
      info: info,
      currentVersion: _version,
      downloader: const AppUpdateDownloader(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.info_outline_rounded),
      title: Text(_version.isEmpty ? appName : '$appName · $_version'),
      subtitle: const Text('基于订阅的 VPN 客户端'),
      trailing: _checkingUpdate
          ? Text('检查中...', style: AppTextStyles.caption())
          : _updateAvailable
          ? TextButton(
              onPressed: _openUpdate,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: AppColors.cyan,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('检查更新'),
            )
          : Text(
              '最新',
              style: AppTextStyles.caption(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _CompactSwitchTile extends StatelessWidget {
  const _CompactSwitchTile({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget title;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: title,
      subtitle: subtitle,
      trailing: Transform.scale(
        scale: 0.82,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.cyan,
        ),
      ),
    );
  }
}
