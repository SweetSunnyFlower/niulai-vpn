import 'package:flutter_v2ray/flutter_v2ray.dart';

import '../models/proxy_node.dart';

class Hysteria2ConfigBuilder {
  const Hysteria2ConfigBuilder._();

  static String build(ProxyNode node) {
    return _Hysteria2Url(url: node.url).getFullConfiguration();
  }
}

class _Hysteria2Url extends V2RayURL {
  _Hysteria2Url({required super.url}) {
    if (!url.startsWith('hysteria2://') && !url.startsWith('hy2://')) {
      throw ArgumentError('url is invalid');
    }
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty || parsed.userInfo.isEmpty) {
      throw ArgumentError('url is invalid');
    }
    uri = parsed;
    _sni =
        uri.queryParameters['sni'] ?? uri.queryParameters['peer'] ?? uri.host;
    final insecureValue =
        uri.queryParameters['insecure'] ?? uri.queryParameters['allowInsecure'];
    _allowInsecure = insecureValue != '0' && insecureValue != 'false';
    _obfsType = uri.queryParameters['obfs'];
    _obfsPassword = uri.queryParameters['obfs-password'];

    streamSetting = {
      'security': 'tls',
      'tcpSettings': null,
      'kcpSettings': null,
      'wsSettings': null,
      'httpSettings': null,
      'tlsSettings': {
        'allowInsecure': _allowInsecure,
        'serverName': _sni,
        'alpn': ['h3'],
        'minVersion': null,
        'maxVersion': null,
        'preferServerCipherSuites': null,
        'cipherSuites': null,
        'fingerprint': null,
        'certificates': null,
        'disableSystemRoot': null,
        'enableSessionResumption': null,
        'show': false,
        'publicKey': null,
        'shortId': null,
        'spiderX': null,
      },
      'quicSettings': null,
      'realitySettings': null,
      'grpcSettings': null,
      'dsSettings': null,
      'sockopt': null,
    };
  }

  late final Uri uri;
  late final String _sni;
  late final bool _allowInsecure;
  String? _obfsType;
  String? _obfsPassword;

  @override
  String get address => uri.host;

  @override
  int get port => uri.hasPort ? uri.port : super.port;

  @override
  String get remark => Uri.decodeFull(uri.fragment.replaceAll('+', '%20'));

  @override
  bool get allowInsecure => _allowInsecure;

  @override
  Map<String, dynamic> get outbound1 => {
    'tag': 'proxy',
    'protocol': 'hysteria2',
    'settings': {
      'servers': [
        {
          'address': address,
          'port': port,
          'auth': uri.userInfo,
          if (_obfsType != null)
            'obfs': {'type': _obfsType, 'password': ?_obfsPassword},
        },
      ],
      'vnext': null,
      'response': null,
      'network': null,
      'domainStrategy': null,
      'redirect': null,
      'userLevel': null,
      'inboundTag': null,
      'secretKey': null,
      'peers': null,
    },
    'streamSettings': streamSetting,
    'proxySettings': null,
    'sendThrough': null,
  };
}
