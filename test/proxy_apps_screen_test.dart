import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpn/screens/proxy_apps_screen.dart';
import 'package:vpn/state/app_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows title', (tester) async {
    final controller = AppController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: ProxyAppsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('VPN APP'), findsOneWidget);
  });
}
