# 指定 APP 直连 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将设置页“仅代理”改为“指定 APP 直连”，支持搜索/勾选 APP，连接时把这些 APP 传入 `flutter_v2ray.blockedApps`。

**Architecture:** 使用 SharedPreferences 保存开关和包名列表，使用 Android MethodChannel 获取已安装 APP，`AppController` 连接时把包名列表传入 `startV2Ray`。

**Tech Stack:** Flutter、Provider、SharedPreferences、flutter_v2ray、MethodChannel、flutter_test。

---

## File Structure

- Create: `lib/services/installed_apps_service.dart`
- Create: `lib/screens/proxy_apps_screen.dart`
- Modify: `lib/services/storage_service.dart`
- Modify: `lib/state/app_controller.dart`
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/main.dart`
- Modify: `android/app/src/main/kotlin/cn/vexai/fuck/MainActivity.kt`
- Test: `test/storage_service_test.dart`
- Test: `test/proxy_apps_screen_test.dart`

---

### Task 1: Persistence

**Files:**
- Modify: `lib/services/storage_service.dart`
- Test: `test/storage_service_test.dart`

- [ ] **Step 1: Add constants and methods**

```dart
static const _proxyAppsEnabledKey = 'proxy_apps_enabled_v1';
static const _proxyAppsListKey = 'proxy_apps_list_v1';

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
```

- [ ] **Step 2: Extend test**

```dart
test('persists proxy apps settings', () async {
  final store = StorageService();

  await store.saveProxyAppsEnabled(true);
  await store.saveProxyAppsList(['com.a', 'com.b']);

  expect(await store.loadProxyAppsEnabled(), isTrue);
  expect(await store.loadProxyAppsList(), ['com.a', 'com.b']);
});
```

- [ ] **Step 3: Run test**

Run: `flutter test test/storage_service_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/services/storage_service.dart test/storage_service_test.dart
git commit -m "feat: persist proxy apps settings"
```

---

### Task 2: Installed apps service

**Files:**
- Create: `lib/services/installed_apps_service.dart`
- Modify: `android/app/src/main/kotlin/cn/vexai/fuck/MainActivity.kt`

- [ ] **Step 1: Native channel**

In `MainActivity.configureFlutterEngine`, add:

```kotlin
MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "app/installed_apps",
).setMethodCallHandler { call, result ->
    if (call.method == "list") {
        val packages = packageManager.getInstalledApplications(0)
        val apps = packages.map {
            mapOf(
                "packageName" to it.packageName,
                "label" to (packageManager.getApplicationLabel(it).toString()),
            )
        }
        result.success(apps)
    } else {
        result.notImplemented()
    }
}
```

- [ ] **Step 2: Dart service**

```dart
import 'package:flutter/services.dart';

class InstalledApp {
  const InstalledApp({required this.packageName, required this.label});
  final String packageName;
  final String label;
}

class InstalledAppsService {
  static const _channel = MethodChannel('app/installed_apps');

  Future<List<InstalledApp>> list() async {
    final result = await _channel.invokeMethod<List<dynamic>>('list');
    return (result ?? const [])
        .whereType<Map>()
        .map((item) => InstalledApp(
              packageName: '${item['packageName'] ?? ''}',
              label: '${item['label'] ?? ''}',
            ))
        .where((app) => app.packageName.isNotEmpty)
        .toList();
  }
}
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze --no-pub`
Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git add lib/services/installed_apps_service.dart android/app/src/main/kotlin/cn/vexai/fuck/MainActivity.kt
git commit -m "feat: add installed apps service"
```

---

### Task 3: AppController

**Files:**
- Modify: `lib/state/app_controller.dart`

- [ ] **Step 1: Add fields**

```dart
bool proxyAppsEnabled = false;
List<String> proxyApps = [];
```

- [ ] **Step 2: Load settings in init**

```dart
proxyAppsEnabled = await _storageService.loadProxyAppsEnabled();
proxyApps = await _storageService.loadProxyAppsList();
```

- [ ] **Step 3: Add setters**

```dart
Future<void> setProxyAppsEnabled(bool value) async {
  proxyAppsEnabled = value;
  await _storageService.saveProxyAppsEnabled(value);
  notifyListeners();
}

Future<void> setProxyApps(List<String> value) async {
  proxyApps = value;
  await _storageService.saveProxyAppsList(value);
  notifyListeners();
}
```

- [ ] **Step 4: Pass blockedApps**

In `connect()` before `startV2Ray`:

```dart
final blockedApps = proxyAppsEnabled ? proxyApps : null;
```

Pass:

```dart
blockedApps: blockedApps,
```

- [ ] **Step 5: Analyze and test**

Run: `flutter analyze --no-pub && flutter test --no-pub`
Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add lib/state/app_controller.dart
git commit -m "feat: use proxy apps in connection"
```

---

### Task 4: ProxyAppsScreen

**Files:**
- Create: `lib/screens/proxy_apps_screen.dart`
- Test: `test/proxy_apps_screen_test.dart`

- [ ] **Step 1: Write screen**

```dart
class ProxyAppsScreen extends StatefulWidget {
  const ProxyAppsScreen({super.key});

  @override
  State<ProxyAppsScreen> createState() => _ProxyAppsScreenState();
}

class _ProxyAppsScreenState extends State<ProxyAppsScreen> {
  final _service = InstalledAppsService();
  late final AppController _controller;
  List<InstalledApp> _apps = [];
  List<InstalledApp> _filtered = [];
  Set<String> _selected = {};
  bool _loading = true;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<AppController>();
    _selected = _controller.proxyApps.toSet();
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
    if (q.isEmpty) return apps;
    return apps
        .where((app) =>
            app.label.toLowerCase().contains(q) ||
            app.packageName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _save() async {
    await _controller.setProxyApps(_selected.toList());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '直连 APP',
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [
                TextButton(onPressed: _save, child: const Text('保存')),
              ],
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
                          subtitle: Text(app.packageName),
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
```

- [ ] **Step 2: Widget test**

```dart
testWidgets('shows title', (tester) async {
  final controller = AppController();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: const MaterialApp(home: ProxyAppsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('直连 APP'), findsOneWidget);
});
```

- [ ] **Step 3: Run test**

Run: `flutter test test/proxy_apps_screen_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/proxy_apps_screen.dart test/proxy_apps_screen_test.dart
git commit -m "feat: add proxy apps screen"
```

---

### Task 5: Settings and route

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Replace switch**

In settings connection behavior, replace `_CompactSwitchTile` for proxyOnly:

```dart
_CompactSwitchTile(
  value: controller.proxyAppsEnabled,
  onChanged: controller.setProxyAppsEnabled,
  title: const Text('指定 APP 直连'),
  subtitle: const Text('开启后仅勾选的 APP 不走 VPN'),
),
if (controller.proxyAppsEnabled) ...[
  const Divider(),
  ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.apps_rounded),
    title: const Text('直连 APP'),
    subtitle: Text('已选择 ${controller.proxyApps.length} 个'),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.of(context).pushNamed('/proxy-apps'),
  ),
],
```

- [ ] **Step 2: Add route**

In `main.dart`, import and route:

```dart
import 'screens/proxy_apps_screen.dart';

'/proxy-apps': (context) => const ProxyAppsScreen(),
```

- [ ] **Step 3: Analyze and test**

Run: `flutter analyze --no-pub && flutter test --no-pub`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings_screen.dart lib/main.dart
git commit -m "feat: add proxy apps entry"
```

---

### Task 6: Final verification

- [ ] **Step 1: Run full checks**

```bash
flutter analyze --no-pub
flutter test --no-pub
```

- [ ] **Step 2: Manual smoke test**

1. 打开设置页。
2. 开启“指定 APP 直连”。
3. 进入“直连 APP”。
4. 搜索并勾选一个 APP。
5. 保存并连接 VPN。
6. 确认该 APP 走直连。

- [ ] **Step 3: Commit any final fixes**

```bash
git add -A
git commit -m "test: finalize proxy apps"
```

---

## Self-Review

- Spec coverage: all requirements map to Tasks 1-5.
- Placeholder scan: no TODO/TBD placeholders.
- Type consistency: storage method names and AppController fields are consistent.
