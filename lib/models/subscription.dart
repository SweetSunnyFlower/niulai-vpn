import 'proxy_node.dart';

class Subscription {
  Subscription({
    required this.url,
    this.name = '',
    this.lastUpdated,
    List<ProxyNode>? nodes,
  }) : nodes = nodes ?? [];

  final String url;
  String name;
  DateTime? lastUpdated;
  List<ProxyNode> nodes;

  String get id => url;

  String get displayName {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return '订阅';
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'name': name,
      'last_updated': lastUpdated?.toIso8601String(),
      'nodes': nodes.map((node) => node.toJson()).toList(),
    };
  }

  static Subscription? fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      return null;
    }
    final rawNodes = json['nodes'] as List<dynamic>? ?? const [];
    final nodes = rawNodes
        .whereType<Map<String, dynamic>>()
        .map(ProxyNode.fromJson)
        .whereType<ProxyNode>()
        .toList();
    final lastUpdated = json['last_updated'] as String?;
    return Subscription(
      url: url,
      name: json['name'] as String? ?? '',
      lastUpdated: lastUpdated == null ? null : DateTime.tryParse(lastUpdated),
      nodes: nodes,
    );
  }
}
