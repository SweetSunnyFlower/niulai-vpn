import 'package:flutter_test/flutter_test.dart';
import 'package:vpn/core/version_utils.dart';

void main() {
  test('compares version numbers numerically', () {
    expect(VersionUtils.compare('1.10.0', '1.9.0'), greaterThan(0));
    expect(VersionUtils.compare('v1.0.0', '1.0.0'), 0);
    expect(VersionUtils.compare('1.0.0+1', '1.0.0'), 0);
    expect(VersionUtils.isNewer('1.0.1', '1.0.0'), isTrue);
    expect(VersionUtils.isNewer('1.0.0', '1.0.0'), isFalse);
  });
}
