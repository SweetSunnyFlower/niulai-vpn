import 'dart:async';
import 'dart:io';

class LatencyService {
  /// Measures TCP connect latency to [host]:[port]. Returns null on timeout or
  /// connection failure.
  Future<int?> ping(String host, int port) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 8),
      );
      final latency = stopwatch.elapsedMilliseconds;
      socket.destroy();
      return latency;
    } catch (_) {
      return null;
    }
  }
}
