class VersionUtils {
  const VersionUtils._();

  static int compare(String left, String right) {
    final leftParts = _parse(left);
    final rightParts = _parse(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      final comparison = leftValue.compareTo(rightValue);
      if (comparison != 0) {
        return comparison;
      }
    }
    return 0;
  }

  static bool isNewer(String candidate, String current) {
    return compare(candidate, current) > 0;
  }

  static List<int> _parse(String version) {
    final normalized = version
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first;
    return normalized
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
