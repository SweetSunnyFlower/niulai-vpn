import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpn/models/proxy_node.dart';
import 'package:vpn/services/hysteria2_config_builder.dart';

void main() {
  test('builds hysteria2 config from link', () {
    final node = ProxyNode.fromUrl(
      'hysteria2://password@example.com:443?insecure=1&sni=cdn.example.com#Hy2',
    );
    final config = jsonDecode(Hysteria2ConfigBuilder.build(node!));
    final outbound = config['outbounds'][0] as Map<String, dynamic>;
    final server = (outbound['settings']['servers'] as List).single;

    expect(outbound['protocol'], 'hysteria2');
    expect(server['address'], 'example.com');
    expect(server['auth'], 'password');
    expect(
      outbound['streamSettings']['tlsSettings']['serverName'],
      'cdn.example.com',
    );
    expect(outbound['streamSettings']['tlsSettings']['allowInsecure'], true);
  });
}
