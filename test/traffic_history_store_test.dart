import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpn/services/traffic_history_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('writes and reads traffic history', () async {
    final store = TrafficHistoryStore();
    final time = DateTime(2026, 9, 13, 10);

    await store.addTraffic(time: time, uploadBytes: 100, downloadBytes: 200);

    final days = await store.loadDays(
      DateTime(2026, 9, 13),
      DateTime(2026, 9, 13),
    );

    expect(days.single.date, DateTime(2026, 9, 13));
    expect(days.single.upload, 100);
    expect(days.single.download, 200);
    expect(days.single.hours[10]?.upload, 100);
  });

  test('prunes data older than 30 days', () async {
    final store = TrafficHistoryStore();
    final old = DateTime(2026, 8, 1);
    final now = DateTime(2026, 9, 13);

    await store.addTraffic(time: old, uploadBytes: 10, downloadBytes: 20);
    await store.pruneBefore(now.subtract(const Duration(days: 30)));

    final days = await store.loadDays(old, now);
    expect(days, isEmpty);
  });
}
