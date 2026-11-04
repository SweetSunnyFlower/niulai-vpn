class Formatters {
  const Formatters._();

  static String latency(int? milliseconds) {
    if (milliseconds == null || milliseconds < 0) {
      return '--';
    }
    if (milliseconds < 1000) {
      return '${milliseconds}ms';
    }
    return '${(milliseconds / 1000).toStringAsFixed(1)}s';
  }

  static String speed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) {
      return '0 B/s';
    }
    const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var value = bytesPerSecond.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }

  static String traffic(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }
}
