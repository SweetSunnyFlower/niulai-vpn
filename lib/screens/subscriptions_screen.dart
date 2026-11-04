import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/subscription.dart';
import '../state/app_controller.dart';
import '../widgets/app_ui.dart';
import '../widgets/gradient_background.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final subscriptions = controller.subscriptions;
    final nodes = subscriptions.fold<int>(
      0,
      (sum, item) => sum + item.nodes.length,
    );
    final refreshing = subscriptions
        .where((item) => controller.isRefreshingSubscription(item.id))
        .length;
    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '订阅数据源',
              leading: IconButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
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
                  onPressed: () => _showForm(context),
                  tooltip: '添加数据源',
                  icon: const Icon(
                    Icons.add_link_sharp,
                    color: AppColors.textPrimary,
                    size: 26,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: _Stats(
                sources: subscriptions.length,
                nodes: nodes,
                refreshing: refreshing,
              ),
            ),
            const SizedBox(height: AppSpacing.card),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final error = await controller.refreshAllSubscriptions();
                  if (error != null && context.mounted) {
                    await showAppError(context, error);
                  }
                },
                color: AppColors.cyan,
                child: subscriptions.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.page,
                          80,
                          AppSpacing.page,
                          AppSpacing.screenBottom,
                        ),
                        children: const [
                          AppEmptyState(
                            icon: Icons.rss_feed_rounded,
                            title: '暂无数据源',
                            message: '点击右上角 + 添加订阅链接',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.page,
                          0,
                          AppSpacing.page,
                          AppSpacing.screenBottom,
                        ),
                        itemCount: subscriptions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.item),
                        itemBuilder: (_, i) {
                          final item = subscriptions[i];
                          return _SourceCard(
                            subscription: item,
                            refreshing: controller.isRefreshingSubscription(
                              item.id,
                            ),
                            onTap: () => _openNodes(context, item),
                            onEdit: () => _showForm(context, item),
                            onRefresh: () => _refreshSource(context, item),
                            onDelete: () => _confirmDelete(context, item),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context, [
    Subscription? subscription,
  ]) async {
    final controller = context.read<AppController>();
    final added = await showModalBottomSheet<Subscription?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black54,
      builder: (_) => _SubscriptionFormSheet(
        subscription: subscription,
        controller: controller,
      ),
    );

    if (added != null && context.mounted) {
      final error = await controller.refreshSubscription(added);
      if (error != null && context.mounted) {
        await showAppError(context, error);
      }
    }
  }

  void _openNodes(BuildContext context, Subscription subscription) {
    Navigator.of(context).pushNamed('/nodes', arguments: subscription.id);
  }

  Future<void> _refreshSource(
    BuildContext context,
    Subscription subscription,
  ) async {
    final controller = context.read<AppController>();
    final error = await controller.refreshSubscription(subscription);
    if (error != null && context.mounted) {
      await showAppError(context, error);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Subscription item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除数据源？'),
        content: Text('将移除“${item.displayName}”及其节点。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppController>().removeSubscription(item);
    }
  }
}

class _SubscriptionFormSheet extends StatefulWidget {
  const _SubscriptionFormSheet({
    required this.subscription,
    required this.controller,
  });

  final Subscription? subscription;
  final AppController controller;

  @override
  State<_SubscriptionFormSheet> createState() => _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState extends State<_SubscriptionFormSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.subscription?.name ?? '',
  );
  late final TextEditingController _urlController = TextEditingController(
    text: widget.subscription?.url ?? '',
  );

  bool _saving = false;
  String? _error;

  Subscription? get _subscription => widget.subscription;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = _subscription == null
        ? await widget.controller.addSubscription(_urlController.text)
        : (
            error: await widget.controller.updateSubscription(
              subscription: _subscription!,
              name: _nameController.text,
              url: _urlController.text,
            ),
            subscription: null,
          );

    if (!mounted) {
      return;
    }

    if (result.error == null) {
      Navigator.of(context).pop(result.subscription);
    } else {
      setState(() {
        _saving = false;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        10,
        AppSpacing.page,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.page,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _subscription == null ? '添加数据源' : '编辑数据源',
              style: AppTextStyles.screenTitle(),
            ),
            const SizedBox(height: 8),
            Text(
              _subscription == null ? '添加后可在订阅列表中手动同步。' : '订阅链接会自动解析并同步节点。',
              style: AppTextStyles.secondary(fontSize: 13),
            ),
            const SizedBox(height: 18),
            if (_subscription != null) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _urlController,
              autofocus: _subscription == null,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '订阅链接',
                hintText: 'https://example.com/sub/xxxx',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: AppTextStyles.body(color: AppColors.red),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _subscription == null ? '添加' : '保存',
                      style: AppTextStyles.button(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.sources,
    required this.nodes,
    required this.refreshing,
  });
  final int sources, nodes, refreshing;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    padding: const EdgeInsets.all(AppSpacing.card),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: AppMetricTile(
            icon: Icons.rss_feed_rounded,
            value: '$sources',
            label: '数据源',
          ),
        ),
        Expanded(
          child: AppMetricTile(
            icon: Icons.hub_outlined,
            value: '$nodes',
            label: '节点',
          ),
        ),
        Expanded(
          child: AppMetricTile(
            icon: Icons.sync_rounded,
            value: refreshing == 0 ? '已同步' : '$refreshing',
            label: refreshing == 0 ? '状态正常' : '同步中',
          ),
        ),
      ],
    ),
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.subscription,
    required this.refreshing,
    required this.onTap,
    required this.onEdit,
    required this.onRefresh,
    required this.onDelete,
  });
  final Subscription subscription;
  final bool refreshing;
  final VoidCallback onTap, onEdit, onRefresh, onDelete;
  @override
  Widget build(BuildContext context) {
    final d = subscription.lastUpdated;
    final time = d == null
        ? '从未同步'
        : '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return SurfacePanel(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: const Icon(
                  Icons.rss_feed_rounded,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${subscription.nodes.length} 个节点 · $time',
                      style: AppTextStyles.secondary(),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: '编辑',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                onPressed: refreshing ? null : onRefresh,
                tooltip: '立即同步',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.sync_rounded, size: 18),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: '删除',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: refreshing ? null : (subscription.nodes.isEmpty ? 0 : 1),
            minHeight: 4,
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ],
      ),
    );
  }
}
