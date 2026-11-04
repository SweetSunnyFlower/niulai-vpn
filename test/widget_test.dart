import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vpn/models/proxy_node.dart';

void main() {
  test('parses a vless proxy link', () {
    const url =
        'vless://08124b5a-a559-4ffd-89a3-18acb4fdcb10@example.com:40547'
        '?encryption=none&security=none&type=tcp#fish-us7t58i4';

    final node = ProxyNode.fromUrl(url);

    expect(node, isNotNull);
    expect(node!.protocol, ProxyProtocol.vless);
    expect(node.name, 'fish-us7t58i4');
    expect(node.address, 'example.com');
    expect(node.port, 40547);
    expect(node.isConnectable, isTrue);
  });

  test('parses a vmess base64 proxy link', () {
    final json = jsonEncode({
      'ps': 'US Node',
      'add': 'example.com',
      'port': '443',
      'id': '00000000-0000-0000-0000-000000000000',
      'aid': '0',
      'net': 'ws',
      'type': 'none',
      'tls': 'tls',
    });
    final encoded = base64.encode(utf8.encode(json));
    final node = ProxyNode.fromUrl('vmess://$encoded');

    expect(node, isNotNull);
    expect(node!.protocol, ProxyProtocol.vmess);
    expect(node.name, 'US Node');
    expect(node.address, 'example.com');
    expect(node.port, 443);
    expect(node.isConnectable, isTrue);
  });

  test('lists hysteria2 as an unsupported protocol', () {
    final node = ProxyNode.fromUrl(
      'hysteria2://password@example.com:443?insecure=1#Hy2 Node',
    );

    expect(node, isNotNull);
    expect(node!.protocol, ProxyProtocol.hysteria2);
    expect(node.name, 'Hy2 Node');
    expect(node.address, 'example.com');
    expect(node.isConnectable, isFalse);
  });
}
