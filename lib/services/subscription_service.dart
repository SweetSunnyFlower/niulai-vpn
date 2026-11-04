import 'dart:convert';
import 'dart:io';

class SubscriptionService {
  /// Fetches and decodes a subscription. Some providers return raw proxy links,
  /// while others return a base64-encoded block of newline-separated links.
  Future<String> fetch(String url) async {
    final client = HttpClient();

    // The subscription server supplied with this project currently presents an
    // expired certificate. Allowing it here is intentionally scoped to reading
    // the subscription list, not to arbitrary requests made by the app.
    client.badCertificateCallback = (cert, host, port) => true;
    client.connectionTimeout = const Duration(seconds: 25);

    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'NebulaVPN/1.0');
      request.headers.set(HttpHeaders.acceptHeader, 'text/plain, */*');

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final status = response.statusCode;
      if (status < 200 || status >= 300) {
        throw Exception('订阅请求失败，HTTP $status');
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
      return _decodeBody(body);
    } finally {
      client.close(force: true);
    }
  }

  String _decodeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final looksLikeBase64 =
        RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(trimmed) &&
        !trimmed.contains('://');
    if (!looksLikeBase64) {
      return trimmed;
    }

    try {
      var raw = trimmed.replaceAll(RegExp(r'\s'), '');
      while (raw.length % 4 != 0) {
        raw += '=';
      }
      final decoded = utf8.decode(base64.decode(raw), allowMalformed: true);
      if (decoded.contains('://')) {
        return decoded;
      }
    } catch (_) {
      // If base64 decoding fails, fall through to the raw body.
    }

    return trimmed;
  }
}
