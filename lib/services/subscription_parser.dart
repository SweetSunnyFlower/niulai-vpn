import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../models/proxy_node.dart';

class SubscriptionParser {
  List<ProxyNode> parse(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    if (trimmed.startsWith('{')) {
      return _parseSingBox(trimmed);
    }
    if (trimmed.contains('proxies:')) {
      return _parseClash(trimmed);
    }
    return _parseRawLines(trimmed);
  }

  List<ProxyNode> _parseRawLines(String body) {
    final seen = <String>{};
    final nodes = <ProxyNode>[];

    for (final line in body.split(RegExp(r'[\r\n]+'))) {
      final value = line.trim();
      if (value.isEmpty) {
        continue;
      }

      if (!value.contains('://') &&
          RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(value)) {
        final decoded = _tryDecodeBase64(value);
        if (decoded.contains('://')) {
          nodes.addAll(_parseRawLines(decoded));
          continue;
        }
      }

      final node = ProxyNode.fromUrl(value);
      if (node != null && seen.add(node.id)) {
        nodes.add(node);
      }
    }

    return nodes;
  }

  List<ProxyNode> _parseClash(String body) {
    final dynamic yaml = loadYaml(body);
    if (yaml is! Map) {
      return [];
    }

    final dynamic proxies = yaml['proxies'];
    if (proxies is! List) {
      return [];
    }

    final seen = <String>{};
    final nodes = <ProxyNode>[];
    for (final dynamic proxy in proxies) {
      if (proxy is! Map) {
        continue;
      }
      final node = _proxyFromMap(proxy);
      if (node != null && seen.add(node.id)) {
        nodes.add(node);
      }
    }
    return nodes;
  }

  List<ProxyNode> _parseSingBox(String body) {
    final dynamic json = jsonDecode(body);
    if (json is! Map) {
      return [];
    }

    final dynamic outbounds = json['outbounds'];
    if (outbounds is! List) {
      return [];
    }

    final seen = <String>{};
    final nodes = <ProxyNode>[];
    for (final dynamic outbound in outbounds) {
      if (outbound is! Map) {
        continue;
      }
      final node = _singBoxOutboundToNode(outbound);
      if (node != null && seen.add(node.id)) {
        nodes.add(node);
      }
    }
    return nodes;
  }

  ProxyNode? _proxyFromMap(Map proxy) {
    final type = _string(proxy, 'type').toLowerCase();
    final name = _string(proxy, 'name');
    final server = _string(proxy, 'server');
    final port = _int(proxy, 'port');
    if (server.isEmpty || port == null) {
      return null;
    }

    final uuid = _string(proxy, 'uuid');
    final password = _string(proxy, 'password');
    final method = _string(proxy, 'cipher');
    final alterId = _int(proxy, 'alterId') ?? _int(proxy, 'aid') ?? 0;
    final network = _string(proxy, 'network');
    final tls =
        _bool(proxy, 'tls') ||
        _string(proxy, 'security').toLowerCase() == 'tls';
    final security = _string(proxy, 'security').toLowerCase();
    final sni = _string(proxy, 'servername').isNotEmpty
        ? _string(proxy, 'servername')
        : _string(proxy, 'sni');
    final host = _string(proxy, 'host');
    final path = _string(proxy, 'path');
    final fingerprint = _string(proxy, 'client-fingerprint').isNotEmpty
        ? _string(proxy, 'client-fingerprint')
        : _string(proxy, 'fp');
    final flow = _string(proxy, 'flow');
    final insecure = _bool(proxy, 'skip-cert-verify');

    return _buildNode(
      type: type,
      name: name,
      server: server,
      port: port,
      uuid: uuid,
      password: password,
      method: method,
      alterId: alterId,
      network: network,
      tls: tls,
      security: security,
      sni: sni,
      host: host,
      path: path,
      fingerprint: fingerprint,
      flow: flow,
      insecure: insecure,
    );
  }

  ProxyNode? _singBoxOutboundToNode(Map outbound) {
    final type = _string(outbound, 'type').toLowerCase();
    final name = _string(outbound, 'tag');
    final server = _string(outbound, 'server');
    final port = _int(outbound, 'server_port');
    if (server.isEmpty || port == null) {
      return null;
    }

    final uuid = _string(outbound, 'uuid');
    final password = _string(outbound, 'password');
    final method = _string(outbound, 'method');
    final tlsObject = _map(outbound, 'tls');
    final tlsEnabled =
        _bool(tlsObject, 'enabled') ||
        (tlsObject.isNotEmpty && type == 'trojan');
    final sni = _string(tlsObject, 'server_name').isNotEmpty
        ? _string(tlsObject, 'server_name')
        : _string(tlsObject, 'servername');
    final insecure = _bool(tlsObject, 'insecure');
    final transport = _map(outbound, 'transport');
    final network = _string(transport, 'type');
    final path = _string(transport, 'path');
    final host = _string(_map(transport, 'headers'), 'Host');
    final utlsFingerprint = _string(tlsObject, 'utls');
    final fingerprint = utlsFingerprint.isNotEmpty
        ? utlsFingerprint
        : _string(outbound, 'fingerprint');
    final flow = _string(outbound, 'flow');

    final reality = _map(tlsObject, 'reality');
    final security = reality.isNotEmpty ? 'reality' : (tlsEnabled ? 'tls' : '');

    return _buildNode(
      type: type,
      name: name,
      server: server,
      port: port,
      uuid: uuid,
      password: password,
      method: method,
      alterId: _int(outbound, 'alter_id') ?? 0,
      network: network,
      tls: tlsEnabled,
      security: security,
      sni: sni,
      host: host,
      path: path,
      fingerprint: fingerprint,
      flow: flow,
      insecure: insecure,
    );
  }

  ProxyNode? _buildNode({
    required String type,
    required String name,
    required String server,
    required int port,
    String uuid = '',
    String password = '',
    String method = '',
    int alterId = 0,
    String network = '',
    bool tls = false,
    String security = '',
    String sni = '',
    String host = '',
    String path = '',
    String fingerprint = '',
    String flow = '',
    bool insecure = false,
  }) {
    final normalizedType = _normalizeType(type);
    final url = _buildShareUrl(
      type: normalizedType,
      name: name,
      server: server,
      port: port,
      uuid: uuid,
      password: password,
      method: method,
      alterId: alterId,
      network: network,
      tls: tls,
      security: security,
      sni: sni,
      host: host,
      path: path,
      fingerprint: fingerprint,
      flow: flow,
      insecure: insecure,
    );

    if (url != null) {
      final parsed = ProxyNode.fromUrl(url);
      if (parsed != null) {
        return parsed;
      }
    }

    final protocol = _protocolForType(normalizedType);
    final fallbackName = name.isNotEmpty ? name : '$server:$port';
    return ProxyNode(
      url: '$normalizedType://$server:$port',
      protocol: protocol,
      name: fallbackName,
      address: server,
      port: port,
    );
  }

  String? _buildShareUrl({
    required String type,
    required String name,
    required String server,
    required int port,
    String uuid = '',
    String password = '',
    String method = '',
    int alterId = 0,
    String network = '',
    bool tls = false,
    String security = '',
    String sni = '',
    String host = '',
    String path = '',
    String fingerprint = '',
    String flow = '',
    bool insecure = false,
  }) {
    final fragment = Uri.encodeComponent(name);

    switch (type) {
      case 'vmess':
        if (uuid.isEmpty) {
          return null;
        }
        final vmessJson = {
          'v': '2',
          'ps': name,
          'add': server,
          'port': '$port',
          'id': uuid,
          'aid': '$alterId',
          'scy': 'auto',
          'net': network.isEmpty ? 'tcp' : network,
          'type': 'none',
          'host': host,
          'path': path,
          'tls': tls ? 'tls' : '',
          'sni': sni,
          'fp': fingerprint,
        };
        return 'vmess://${base64.encode(utf8.encode(jsonEncode(vmessJson)))}';

      case 'vless':
        if (uuid.isEmpty) {
          return null;
        }
        final vlessParams = <String, String>{
          'encryption': 'none',
          'type': network.isEmpty ? 'tcp' : network,
          'security': security.isEmpty ? (tls ? 'tls' : 'none') : security,
          if (host.isNotEmpty) 'host': host,
          if (path.isNotEmpty) 'path': path,
          if (sni.isNotEmpty) 'sni': sni,
          if (fingerprint.isNotEmpty) 'fp': fingerprint,
          if (flow.isNotEmpty) 'flow': flow,
          if (insecure) 'allowInsecure': '1',
        };
        return 'vless://$uuid@$server:$port?${Uri(queryParameters: vlessParams).query}#$fragment';

      case 'trojan':
        if (password.isEmpty) {
          return null;
        }
        final trojanParams = <String, String>{
          'type': network.isEmpty ? 'tcp' : network,
          'security': tls || security == 'tls' ? 'tls' : 'none',
          if (sni.isNotEmpty) 'sni': sni,
          if (host.isNotEmpty) 'host': host,
          if (path.isNotEmpty) 'path': path,
          if (flow.isNotEmpty) 'flow': flow,
          if (insecure) 'allowInsecure': '1',
        };
        return 'trojan://$password@$server:$port?${Uri(queryParameters: trojanParams).query}#$fragment';

      case 'ss':
        final ssMethod = method.isEmpty ? 'aes-256-gcm' : method;
        final userInfo = base64.encode(utf8.encode('$ssMethod:$password'));
        return 'ss://$userInfo@$server:$port#$fragment';

      case 'hysteria2':
      case 'hysteria':
        if (password.isEmpty) {
          return null;
        }
        final hy2Params = <String, String>{
          if (sni.isNotEmpty) 'sni': sni,
          if (insecure) 'insecure': '1',
        };
        return '$type://$password@$server:$port?${Uri(queryParameters: hy2Params).query}#$fragment';

      case 'tuic':
        if (uuid.isEmpty) {
          return null;
        }
        return 'tuic://$uuid:$password@$server:$port#$fragment';

      default:
        return null;
    }
  }

  String _normalizeType(String type) {
    return switch (type.toLowerCase()) {
      'shadowsocks' || 'ss' => 'ss',
      'shadowsocksr' || 'ssr' => 'ssr',
      'socks' || 'socks5' => 'socks',
      'hysteria2' || 'hy2' || 'hysteria' || 'hy' => 'hysteria2',
      'tuic' => 'tuic',
      'http' => 'http',
      _ => type.toLowerCase(),
    };
  }

  ProxyProtocol _protocolForType(String type) {
    return switch (type) {
      'vless' => ProxyProtocol.vless,
      'vmess' => ProxyProtocol.vmess,
      'trojan' => ProxyProtocol.trojan,
      'ss' => ProxyProtocol.shadowsocks,
      'socks' => ProxyProtocol.socks,
      'ssr' => ProxyProtocol.ssr,
      'hysteria2' || 'hysteria' => ProxyProtocol.hysteria2,
      'tuic' => ProxyProtocol.tuic,
      _ => ProxyProtocol.unknown,
    };
  }

  String _string(Map map, String key) {
    final value = map[key];
    return value?.toString() ?? '';
  }

  int? _int(Map map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  bool _bool(Map map, String key) {
    final value = map[key];
    return value == true || value == 'true' || value == 1;
  }

  Map _map(Map map, String key) {
    final value = map[key];
    return value is Map ? value : const {};
  }

  String _tryDecodeBase64(String raw) {
    var value = raw.replaceAll(RegExp(r'\s'), '');
    while (value.length % 4 != 0) {
      value += '=';
    }
    try {
      return utf8.decode(base64.decode(value), allowMalformed: true);
    } catch (_) {
      return raw;
    }
  }
}
