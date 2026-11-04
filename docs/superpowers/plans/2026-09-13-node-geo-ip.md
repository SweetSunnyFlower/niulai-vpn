# 节点归属地显示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 节点列表显示 IP 归属地，数据来自 ip-api.com，并缓存 24 小时。

**Architecture:** 新增 `GeoIpService` 和 `GeoIpCacheStore`，`NodesScreen` 批量查询，`NodeCard` 显示国家/地区/城市。

**Tech Stack:** Flutter、SharedPreferences、http、flutter_test。

---

## File Structure

- Create: `lib/services/geo_ip_service.dart`
- Create: `lib/services/geo_ip_cache_store.dart`
- Modify: `lib/screens/nodes_screen.dart`
- Modify: `lib/widgets/node_card.dart`
- Test: `test/geo_ip_service_test.dart`
- Test: `test/geo_ip_cache_store_test.dart`

---

### Task 1: GeoIpService

**Files:**
- Create: `lib/services/geo_ip_service.dart`
- Test: `test/geo_ip_service_test.dart`

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn/services/geo_ip_service.dart';

void main() {
  test('parses success response', () {
    final info = GeoIpService.parseResponse({
      'status': 'success',
      'country': '美国',
      'regionName': '加州',
      'city': '洛杉矶',
    });
    expect(info, isNotNull);
    expect(info!.country, '美国');
    expect(info.region, '加州');
    expect(info.city, '洛杉矶');
  });
}
```

- [ ] **Step 2: Implement**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeoIpInfo {
  const GeoIpInfo({
    required this.country,
    required this.region,
    required this.city,
  });
  final String country;
  final String region;
  final String city;
}

class GeoIpService {
  static GeoIpInfo? parseResponse(Map<String, dynamic> json) {
    if (json['status'] != 'success') return null;
    final country = '${json['country'] ?? ''}';
    final region = '${json['regionName'] ?? ''}';
    final city = '${json['city'] ?? ''}';
    if (country.isEmpty && region.isEmpty && city.isEmpty) return null;
    return GeoIpInfo(country: country, region: region, city: city);
  }

  Future<GeoIpInfo?> fetch(String host) async {
    if (host.isEmpty) return null;
    try {
      final uri = Uri.parse('http://ip-api.com/json/$host?lang=zh-CN');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return parseResponse(decoded);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 3: Run test**

Run: `flutter test test/geo_ip_service_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/services/geo_ip_service.dart test/geo_ip_service_test.dart
git commit -m "feat: add geo ip service"
```

---

### Task 2: Cache store

**Files:**
- Create: `lib/services/geo_ip_cache_store.dart`
- Test: `test/geo_ip_cache_store_test.dart`

- [ ] **Step 1: Implement**

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'geo_ip_service.dart';

class GeoIpCacheStore {
  static const _key = 'geo_ip_cache_v1';
  static const ttl = Duration(hours: 24);

  Future<Map<String, GeoIpInfo>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final now = DateTime.now().millisecondsSinceEpoch;
      final result = <String, GeoIpInfo>{};
      decoded.forEach((host, value) {
        if (value is! Map<String, dynamic>) return;
        final time = (value['time'] as num?)?.toInt() ?? 0;
        if (now - time > ttl.inMilliseconds) return;
        final country = '${value['country'] ?? ''}';
        final region = '${value['region'] ?? ''}';
        final city = '${value['city'] ?? ''}';
        result[host] = GeoIpInfo(country: country, region: region, city: city);
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, GeoIpInfo> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, dynamic>{};
    data.forEach((host, info) {
      encoded[host] = {
        'time': DateTime.now().millisecondsSinceEpoch,
        'country': info.country,
        'region': info.region,
        'city': info.city,
      };
    });
    await prefs.setString(_key, jsonEncode(encoded));
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze --no-pub`
Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/services/geo_ip_cache_store.dart test/geo_ip_cache_store_test.dart
git commit -m "feat: add geo ip cache"
```

---

### Task 3: Nodes screen lookup

**Files:**
- Modify: `lib/screens/nodes_screen.dart`

- [ ] **Step 1: Add state**

```dart
final GeoIpService _geoIpService = GeoIpService();
final GeoIpCacheStore _geoIpCacheStore = GeoIpCacheStore();
final Map<String, GeoIpInfo> _geoInfo = {};
final Set<String> _geoLoading = {};
bool _geoLoaded = false;
```

- [ ] **Step 2: Trigger lookup**

In `build`, after obtaining `allNodes`:

```dart
if (!_geoLoaded) {
  _geoLoaded = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadGeo(allNodes);
  });
}
```

- [ ] **Step 3: Implement lookup**

```dart
Future<void> _loadGeo(List<ProxyNode> nodes) async {
  final cached = await _geoIpCacheStore.load();
  setState(() {
    _geoInfo.addAll(cached);
    for (final node in nodes) {
      if (!_geoInfo.containsKey(node.address)) {
        _geoLoading.add(node.address);
      }
    }
  });

  await Future.wait(nodes.map((node) async {
    if (_geoInfo.containsKey(node.address)) return;
    final info = await _geoIpService.fetch(node.address);
    if (!mounted) return;
    setState(() {
      _geoLoading.remove(node.address);
      if (info != null) {
        _geoInfo[node.address] = info;
      }
    });
  }));
  await _geoIpCacheStore.save(_geoInfo);
}
```

- [ ] **Step 4: Pass to NodeCard**

```dart
NodeCard(
  ...
  geoInfo: _geoInfo[node.address],
  geoLoading: _geoLoading.contains(node.address),
)
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/nodes_screen.dart
git commit -m "feat: lookup node geo info"
```

---

### Task 4: NodeCard display

**Files:**
- Modify: `lib/widgets/node_card.dart`

- [ ] **Step 1: Add fields**

```dart
final GeoIpInfo? geoInfo;
final bool geoLoading;
```

- [ ] **Step 2: Show row**

```dart
Text(
  geoLoading
      ? '归属地查询中...'
      : geoInfo == null
      ? '归属地未知'
      : '${geoInfo!.country} · ${geoInfo!.region} · ${geoInfo!.city}',
  style: AppTextStyles.caption(),
)
```

- [ ] **Step 3: Analyze/test**

Run: `flutter analyze --no-pub && flutter test --no-pub`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/node_card.dart
git commit -m "feat: display node geo info"
```

---

### Task 5: Final verification

- [ ] **Step 1: Full checks**

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug
```

- [ ] **Step 2: Manual test**

1. 打开节点浏览器。
2. 观察归属地查询状态。
3. 确认国家/地区/城市显示。
4. 再次进入页面，确认缓存生效。

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "test: finalize node geo ip"
```

---

## Self-Review

- Spec coverage: all requirements map to Tasks 1-4.
- Placeholder scan: no TODO/TBD placeholders.
- Type consistency: `GeoIpInfo`, `GeoIpService`, `GeoIpCacheStore` names are consistent.
