import 'dart:convert';

import 'package:flutter_v2ray/flutter_v2ray.dart';

enum ProxyProtocol {
  vless,
  vmess,
  trojan,
  shadowsocks,
  socks,
  ssr,
  hysteria2,
  tuic,
  unknown,
}

extension ProxyProtocolInfo on ProxyProtocol {
  String get label {
    return switch (this) {
      ProxyProtocol.vless => 'VLESS',
      ProxyProtocol.vmess => 'VMess',
      ProxyProtocol.trojan => 'Trojan',
      ProxyProtocol.shadowsocks => 'Shadowsocks',
      ProxyProtocol.socks => 'SOCKS',
      ProxyProtocol.ssr => 'SSR',
      ProxyProtocol.hysteria2 => 'Hysteria2',
      ProxyProtocol.tuic => 'TUIC',
      ProxyProtocol.unknown => '未知',
    };
  }

  bool get isConnectable {
    return switch (this) {
      ProxyProtocol.vless ||
      ProxyProtocol.vmess ||
      ProxyProtocol.trojan ||
      ProxyProtocol.shadowsocks ||
      ProxyProtocol.socks => true,
      _ => false,
    };
  }
}

class ProxyNode {
  const ProxyNode({
    required this.url,
    required this.protocol,
    required this.name,
    required this.address,
    this.port,
    this.latencyMs,
  });

  final String url;
  final ProxyProtocol protocol;
  final String name;
  final String address;
  final int? port;
  final int? latencyMs;

  String get id => url;

  String get endpoint => port == null ? address : '$address:$port';

  bool get isConnectable => protocol.isConnectable;

  ProxyNode withLatency(int? latencyMs) {
    return ProxyNode(
      url: url,
      protocol: protocol,
      name: name,
      address: address,
      port: port,
      latencyMs: latencyMs,
    );
  }

  /// Parses a standard proxy share link. Supported connection protocols are
  /// handled by the v2ray plugin; other protocols are still listed in the UI.
  static ProxyNode? fromUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty || !url.contains('://')) {
      return null;
    }

    final scheme = url.split('://').first.toLowerCase();
    final protocol = _protocolFromScheme(scheme);

    var name = '';
    var address = '';
    int? port;

    try {
      final parsed = FlutterV2ray.parseFromURL(url);
      name = parsed.remark.trim();
      address = parsed.address;
      port = parsed.port;
    } catch (_) {
      // The plugin only supports vmess/vless/trojan/ss/socks. Fall back to a
      // lightweight parser so unsupported links can still be displayed.
    }

    if (name.isEmpty || address.isEmpty || port == null) {
      final manual = _parseManually(url, scheme);
      if (name.isEmpty) {
        name = manual.name;
      }
      if (address.isEmpty) {
        address = manual.address;
      }
      port ??= manual.port;
    }

    if (address.isEmpty) {
      return null;
    }
    if (name.isEmpty) {
      name = address;
    }

    return ProxyNode(
      url: url,
      protocol: protocol,
      name: name,
      address: address,
      port: port,
    );
  }

  static ProxyProtocol _protocolFromScheme(String scheme) {
    return switch (scheme) {
      'vless' => ProxyProtocol.vless,
      'vmess' => ProxyProtocol.vmess,
      'trojan' => ProxyProtocol.trojan,
      'ss' => ProxyProtocol.shadowsocks,
      'socks' || 'socks5' => ProxyProtocol.socks,
      'ssr' => ProxyProtocol.ssr,
      'hysteria2' || 'hy2' => ProxyProtocol.hysteria2,
      'tuic' => ProxyProtocol.tuic,
      _ => ProxyProtocol.unknown,
    };
  }

  static ({String name, String address, int? port}) _parseManually(
    String url,
    String scheme,
  ) {
    if (scheme == 'vmess') {
      try {
        var raw = url.substring('vmess://'.length);
        while (raw.length % 4 != 0) {
          raw += '=';
        }
        final decoded = jsonDecode(utf8.decode(base64Decode(raw)));
        if (decoded is Map<String, dynamic>) {
          return (
            name: '${decoded['ps'] ?? ''}',
            address: '${decoded['add'] ?? ''}',
            port: int.tryParse('${decoded['port']}'),
          );
        }
      } catch (_) {
        // Ignore malformed vmess payloads.
      }
    }

    if (scheme == 'ssr') {
      try {
        var raw = url.substring('ssr://'.length);
        while (raw.length % 4 != 0) {
          raw += '=';
        }
        final decoded = utf8.decode(base64Decode(raw));
        final uri = Uri.tryParse(decoded);
        if (uri != null) {
          return (
            name: uri.fragment.isNotEmpty
                ? Uri.decodeComponent(uri.fragment)
                : '',
            address: uri.host,
            port: uri.hasPort ? uri.port : null,
          );
        }
      } catch (_) {
        // Ignore malformed SSR payloads.
      }
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return (name: '', address: '', port: null);
    }
    return (
      name: uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : '',
      address: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'protocol': protocol.name,
      'name': name,
      'address': address,
      'port': port,
      'latency_ms': latencyMs,
    };
  }

  static ProxyNode? fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      return null;
    }
    final protocolName = json['protocol'] as String?;
    return ProxyNode(
      url: url,
      protocol: ProxyProtocol.values.firstWhere(
        (protocol) => protocol.name == protocolName,
        orElse: () => ProxyProtocol.unknown,
      ),
      name: json['name'] as String? ?? '未命名节点',
      address: json['address'] as String? ?? '',
      port: json['port'] as int?,
      latencyMs: json['latency_ms'] as int?,
    );
  }
}
