import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'core/app_theme.dart';
import 'core/version_utils.dart';
import 'screens/home_screen.dart';
import 'screens/node_map_screen.dart';
import 'screens/nodes_screen.dart';
import 'screens/proxy_apps_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'services/app_update_downloader.dart';
import 'services/app_update_service.dart';
import 'state/app_controller.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/gradient_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Missing or malformed .env should never block startup.
  }
  final envEndpoint = dotenv.env['UPDATE_ENDPOINT'];
  if (envEndpoint != null && envEndpoint.isNotEmpty) {
    appUpdateEndpoint = envEndpoint;
  }
  runApp(const VpnApp());
}

class VpnApp extends StatefulWidget {
  const VpnApp({super.key});

  @override
  State<VpnApp> createState() => _VpnAppState();
}

class _VpnAppState extends State<VpnApp> {
  final AppController _controller = AppController();
  final AppUpdateService _updateService = AppUpdateService();
  final AppUpdateDownloader _updateDownloader = const AppUpdateDownloader();
  static const _backChannel = MethodChannel('app/back');
  bool _updateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<AppController>(
        builder: (context, controller, _) {
          return MaterialApp(
            title: appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) {
                if (!_updateCheckStarted) {
                  _updateCheckStarted = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      unawaited(_checkForAppUpdate(context));
                    }
                  });
                }
                if (controller.loading) {
                  return const _SplashScreen();
                }
                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop) {
                      _backChannel.invokeMethod('moveTaskToBack');
                    }
                  },
                  child: HomeScreen(
                    onOpenNodes: () =>
                        Navigator.of(context).pushNamed('/nodes'),
                    onOpenSettings: () =>
                        Navigator.of(context).pushNamed('/settings'),
                    onOpenStats: () =>
                        Navigator.of(context).pushNamed('/stats'),
                  ),
                );
              },
            ),
            routes: {
              '/settings': (context) => SettingsScreen(
                onOpenNodes: () => Navigator.of(context).pushNamed('/nodes'),
                onOpenSubscriptions: () =>
                    Navigator.of(context).pushNamed('/subscriptions'),
              ),
              '/nodes': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                return NodesScreen(
                  initialSubscriptionId: args is String ? args : null,
                );
              },
              '/node-map': (context) => const NodeMapScreen(),
              '/subscriptions': (context) => const SubscriptionsScreen(),
              '/stats': (context) => const StatsScreen(),
              '/proxy-apps': (context) => const ProxyAppsScreen(),
            },
          );
        },
      ),
    );
  }

  Future<void> _checkForAppUpdate(BuildContext appContext) async {
    final info = await _updateService.fetchLatest();
    if (!mounted || info == null) {
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    if (!appContext.mounted) {
      return;
    }
    if (!VersionUtils.isNewer(info.version, packageInfo.version)) {
      return;
    }

    await showAppUpdateDialog(
      context: appContext,
      info: info,
      currentVersion: packageInfo.version,
      downloader: _updateDownloader,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.28),
                      blurRadius: 38,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icon.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                appName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
