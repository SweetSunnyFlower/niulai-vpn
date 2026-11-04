import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpn/screens/stats_screen.dart';
import 'package:vpn/state/app_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('stats screen shows zero data placeholders', (tester) async {
    final controller = AppController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('流量统计'), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('上传'), findsWidgets);
  });
}
