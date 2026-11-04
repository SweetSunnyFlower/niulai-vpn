# 指定 APP 直连设计

日期：2026-09-13

## 背景

当前 APP 连接 VPN 后，所有系统流量都会走 VPN。用户希望可以指定部分 APP 直连，不经过 VPN。当前 `flutter_v2ray` 已支持 `blockedApps`，可以直接传入需要直连的包名列表。

## 目标

- 将设置页原有“仅代理”开关改造成“指定 APP 直连”。
- 开关默认关闭。
- 关闭时：所有 APP 走 VPN。
- 开启时：用户选择的 APP 走直连，其他 APP 继续走 VPN。
- 用户可以搜索、勾选需要直连的 APP。
- 选择结果持久化，下次进入自动回显。

## 非目标

- 不做白名单模式。
- 不做本地 HTTP/SOCKS 代理配置。
- 不处理 iOS。
- 不实现按域名分流。

## 方案

使用 `flutter_v2ray` 的 `blockedApps` 参数实现直连列表。

## 数据模型

新增 SharedPreferences：

- `proxy_apps_enabled_v1`：是否启用“指定 APP 直连”
- `proxy_apps_list_v1`：直连 APP 包名列表

列表格式：

```json
["com.google.android.youtube", "org.telegram.messenger"]
```

## 页面结构

### SettingsScreen

- 原“仅代理”开关改为“指定 APP 直连”
- 开关关闭：不显示 APP 选择入口
- 开关开启：显示“直连 APP”入口
- 入口副标题显示已选择数量
- 点击入口进入 `ProxyAppsScreen`

### ProxyAppsScreen

- 显示已安装 APP 列表
- 支持搜索
- 支持勾选/取消勾选
- 保存选择结果
- 返回设置页后更新已选数量

## 数据流

```text
设置页开关
  → 保存 proxy_apps_enabled
  → 开启后进入 ProxyAppsScreen
  → 保存 proxy_apps_list
  → AppController.connect()
  → blockedApps = proxy_apps_list
  → flutter_v2ray.startV2Ray(blockedApps: ...)
```

## 连接逻辑

`AppController.connect()`：

- 如果 `proxy_apps_enabled == false`：`blockedApps` 传空。
- 如果 `proxy_apps_enabled == true`：`blockedApps` 传 `proxy_apps_list`。
- 包名列表过滤掉已卸载 APP。

## 错误处理

- 获取已安装 APP 失败：显示空状态和重试按钮。
- 没有读取 APP 列表权限：提示无法读取应用列表。
- 保存失败：提示保存失败，不关闭页面。
- 连接时忽略已卸载 APP。
- 开关开启但没有勾选任何 APP：等价于所有 APP 走 VPN。

## 测试方案

### 单元测试

- 开关状态保存/读取。
- 直连列表保存/读取。
- 过滤已卸载 APP。

### Widget 测试

- 开关关闭时隐藏“直连 APP”入口。
- 开关开启时显示“直连 APP”入口。
- `ProxyAppsScreen` 搜索和勾选。
- 保存后回显。

## 验收标准

- 设置页开关默认关闭。
- 开启后可以进入 APP 选择页。
- APP 选择页支持搜索和勾选。
- 选择结果持久化。
- 连接时 `blockedApps` 正确传入。
- `flutter analyze` 无错误。
- `flutter test` 全部通过。
