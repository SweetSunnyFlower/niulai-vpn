# 牛来VPN

Flutter VPN 客户端。

## APP 更新检查接口

APP 每次启动时都会调用以下接口检查更新：

```text
GET https://version.vexai.cn/vpn
```

接口失败时静默降级，不影响当前 APP 使用。

### 响应格式

```json
{
  "version": "1.1.0",
  "force_update": false,
  "download_url": "https://example.com/vpn-1.1.0.apk",
  "release_notes": "修复若干问题，提升稳定性。"
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `version` | string | 是 | 最新版本号，例如 `1.1.0` |
| `force_update` | boolean | 是 | 是否强制升级；为 `true` 时弹窗不可关闭 |
| `download_url` | string | 是 | 安装包下载地址，APP 使用外部浏览器打开 |
| `release_notes` | string | 否 | 更新说明 |

版本比较规则：

- 忽略版本号前的 `v` 前缀。
- 忽略 `+` 后的构建号。
- 按 `.` 分段逐段比较数字，例如 `1.10.0 > 1.9.0`。

### 本地测试

项目内置了一个本地 mock 服务：

```bash
python3 tool/version_server.py
```

默认监听 `8090` 端口，也可以指定端口：

```bash
PORT=8090 python3 tool/version_server.py
```

测试接口：

```bash
curl http://127.0.0.1:8090/vpn
```

在手机上联调时，把 `127.0.0.1` 换成本机内网 IP，例如：

```text
http://192.168.1.6:8090/vpn
```

运行 APP 时通过 `UPDATE_ENDPOINT` 覆盖正式接口：

```bash
flutter run --dart-define=UPDATE_ENDPOINT=http://192.168.1.6:8090/vpn
```

也可以直接使用 `.env` 文件。项目根目录的 `.env` 中配置：

```env
UPDATE_ENDPOINT=http://192.168.1.6:8090/vpn
```

`.env` 优先级高于 `--dart-define` 的默认值，因此本地测试时只需要改 `.env`，无需每次输入长参数。

正式构建不传该参数，默认使用：

```text
https://version.vexai.cn/vpn
```
