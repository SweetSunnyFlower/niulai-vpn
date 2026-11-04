import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../core/app_theme.dart';
import '../services/app_update_downloader.dart';
import '../services/app_update_service.dart';

Future<void> showAppUpdateDialog({
  required BuildContext context,
  required AppUpdateInfo info,
  required String currentVersion,
  required AppUpdateDownloader downloader,
}) async {
  final force = info.forceUpdate;
  await showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (dialogContext) {
      return PopScope(
        canPop: !force,
        child: AlertDialog(
          title: Text(force ? '需要更新' : '发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本：$currentVersion'),
              const SizedBox(height: 4),
              Text('最新版本：${info.version}'),
              if (info.releaseNotes != null) ...[
                const SizedBox(height: 12),
                Text(
                  info.releaseNotes!,
                  style: AppTextStyles.secondary(fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('稍后'),
              ),
            TextButton(
              onPressed: () => _downloadAndInstall(
                dialogContext,
                context,
                info.downloadUrl,
                downloader,
              ),
              child: const Text('立即更新'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _downloadAndInstall(
  BuildContext dialogContext,
  BuildContext appContext,
  String downloadUrl,
  AppUpdateDownloader downloader,
) async {
  if (dialogContext.mounted) {
    Navigator.of(dialogContext).pop();
  }
  await showDialog<void>(
    context: appContext,
    barrierDismissible: false,
    builder: (_) => AppUpdateDownloadDialog(
      downloader: downloader,
      downloadUrl: downloadUrl,
    ),
  );
}

class AppUpdateDownloadDialog extends StatefulWidget {
  const AppUpdateDownloadDialog({
    super.key,
    required this.downloader,
    required this.downloadUrl,
  });

  final AppUpdateDownloader downloader;
  final String downloadUrl;

  @override
  State<AppUpdateDownloadDialog> createState() =>
      _AppUpdateDownloadDialogState();
}

class _AppUpdateDownloadDialogState extends State<AppUpdateDownloadDialog> {
  double? _progress;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final file = await widget.downloader.download(
        widget.downloadUrl,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _progress = progress);
          }
        },
      );
      if (!mounted) {
        return;
      }
      setState(() => _opening = true);
      final result = await OpenFilex.open(file.path);
      if (!mounted) {
        return;
      }
      if (result.type != ResultType.done) {
        setState(() {
          _opening = false;
          _error = '无法打开安装包';
        });
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '下载失败，请稍后重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProgress = _progress != null && _progress! >= 0;
    return AlertDialog(
      title: Text(
        _opening
            ? '正在打开安装包'
            : _error == null
            ? '正在下载更新'
            : '下载失败',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.red))
          else if (_opening)
            const Center(child: CircularProgressIndicator())
          else ...[
            LinearProgressIndicator(value: hasProgress ? _progress : null),
            const SizedBox(height: 12),
            Text(
              hasProgress
                  ? '${(_progress! * 100).toStringAsFixed(0)}%'
                  : '正在连接下载...',
              style: AppTextStyles.secondary(),
            ),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}
