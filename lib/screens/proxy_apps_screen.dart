import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../services/installed_apps_service.dart';
import '../state/app_controller.dart';
import '../widgets/app_ui.dart';
import '../widgets/gradient_background.dart';

class ProxyAppsScreen extends StatefulWidget {
  const ProxyAppsScreen({super.key});

  @override
  State<ProxyAppsScreen> createState() => _ProxyAppsScreenState();
}

class _ProxyAppsScreenState extends State<ProxyAppsScreen> {
  final _service = InstalledAppsService();
  List<InstalledApp> _apps = [];
  List<InstalledApp> _filtered = [];
  Set<String> _selected = {};
  bool _loading = true;
  bool _initialized = false;
  String _query = '';
  final Map<String, String> _iconCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    _selected = context.read<AppController>().proxyApps.toSet();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final apps = await _service.list();
    apps.sort((a, b) => a.label.compareTo(b.label));
    setState(() {
      _apps = apps;
      _filtered = _filter(apps, _query);
      _loading = false;
    });
  }

  List<InstalledApp> _filter(List<InstalledApp> apps, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return apps;
    }
    return apps
        .where(
          (app) =>
              app.label.toLowerCase().contains(q) ||
              app.packageName.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _save() async {
    await context.read<AppController>().setProxyApps(_selected.toList());
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'VPN APP',
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [TextButton(onPressed: _save, child: const Text('保存'))],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.dense,
              ),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索 APP',
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value;
                    _filtered = _filter(_apps, value);
                  });
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final app = _filtered[index];
                        return CheckboxListTile(
                          value: _selected.contains(app.packageName),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(app.packageName);
                              } else {
                                _selected.remove(app.packageName);
                              }
                            });
                          },
                          title: Text(app.label),
                          subtitle: Text(
                            '${app.packageName}${app.isSystemApp ? ' · 系统' : ''}',
                          ),
                          secondary: _LazyAppIcon(
                            packageName: app.packageName,
                            service: _service,
                            cache: _iconCache,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LazyAppIcon extends StatefulWidget {
  const _LazyAppIcon({
    required this.packageName,
    required this.service,
    required this.cache,
  });

  final String packageName;
  final InstalledAppsService service;
  final Map<String, String> cache;

  @override
  State<_LazyAppIcon> createState() => _LazyAppIconState();
}

class _LazyAppIconState extends State<_LazyAppIcon> {
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.cache[widget.packageName] != null
        ? Future.value(widget.cache[widget.packageName])
        : widget.service.loadIcon(widget.packageName);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (value != null && value.isNotEmpty) {
          widget.cache[widget.packageName] = value;
          try {
            return CircleAvatar(
              backgroundImage: MemoryImage(base64Decode(value)),
            );
          } catch (_) {
            return const Icon(Icons.android_rounded);
          }
        }
        return const SizedBox(
          width: 40,
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}
