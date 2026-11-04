# 节点归属地显示设计

日期：2026-09-13

## 背景

节点浏览器当前只显示协议、端口、延迟等信息，用户无法判断节点所在地区。希望增加节点 IP 归属地展示，数据来源为 ip-api.com。

## 目标

- 节点卡片展示“国家 / 地区 / 城市”。
- 进入节点页后，对当前列表所有节点并发查询。
- 查询结果缓存 24 小时。
- 查询中显示“归属地查询中...”。
- 查询失败显示“归属地未知”。

## 非目标

- 不做地图展示。
- 不做节点按地区筛选。
- 不做 VPN 出口 IP 实时检测。

## 方案

使用 `ip-api.com/json/{host}?lang=zh-CN` 查询节点地址归属地。

## 数据模型

`GeoIpInfo`：

```dart
class GeoIpInfo {
  final String country;
  final String region;
  final String city;
}
```

缓存格式：

```json
{
  "117.55.233.218": {
    "time": 1789290000000,
    "country": "美国",
    "region": "加州",
    "city": "洛杉矶"
  }
}
```

## 服务设计

### GeoIpService

- 请求：
  - `http://ip-api.com/json/{host}?lang=zh-CN`
- 解析：
  - `country`
  - `regionName`
  - `city`
- 失败或限流时返回 null。

### GeoIpCacheStore

- SharedPreferences 持久化。
- 缓存过期时间：24 小时。
- 读取时自动过滤过期数据。

## 页面展示

`NodeCard` 增加一行：

- 查询中：`归属地查询中...`
- 成功：`美国 · 加州 · 洛杉矶`
- 失败：`归属地未知`

## 查询流程

```text
进入节点页
  → 收集所有节点 address
  → 批量异步查询 GeoIpService
  → 缓存命中直接返回
  → 未命中请求 ip-api.com
  → 更新 NodeCard
```

## 错误处理

- 网络失败：显示“归属地未知”。
- 限流：显示“归属地未知”。
- 节点地址为空：不查询。
- 缓存损坏：忽略并重新查询。

## 测试方案

### 单元测试

- GeoIpService 成功解析。
- GeoIpService 失败返回 null。
- 缓存命中。
- 缓存过期后重新查询。

### Widget 测试

- NodeCard 显示归属地。
- 查询中状态。
- 查询失败状态。

## 验收标准

- 节点卡片展示国家 / 地区 / 城市。
- 查询结果缓存 24 小时。
- 查询失败不影响节点列表。
- `flutter analyze` 无错误。
- `flutter test` 全部通过。
