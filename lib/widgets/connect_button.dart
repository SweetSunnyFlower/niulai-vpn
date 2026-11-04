import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../state/app_controller.dart';

class ConnectButton extends StatefulWidget {
  const ConnectButton({
    super.key,
    required this.state,
    required this.enabled,
    required this.onPressed,
  });

  final VpnConnectionState state;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _wasConnected = false;

  bool get _connected => widget.state == VpnConnectionState.connected;

  @override
  void initState() {
    super.initState();
    _wasConnected = _connected;
    _syncBreathAnimation();
  }

  @override
  void didUpdateWidget(covariant ConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final connected = _connected;
    if (connected != _wasConnected) {
      _wasConnected = connected;
      _syncBreathAnimation();
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  void _syncBreathAnimation() {
    if (_connected) {
      _breathController.repeat(reverse: true);
    } else {
      _breathController
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(widget.state);
    final busy =
        widget.state == VpnConnectionState.connecting ||
        widget.state == VpnConnectionState.disconnecting;

    return Semantics(
      button: true,
      label: _connected ? '断开 VPN' : '连接 VPN',
      child: GestureDetector(
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _connected ? 1 : 0.98,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          child: AnimatedBuilder(
            animation: _breathController,
            builder: (context, child) {
              final breath = _breathController.value;
              final glowAlpha = _connected
                  ? 0.22 + 0.18 * breath
                  : (widget.enabled ? 0.24 : 0.08);
              final shadowAlpha = _connected
                  ? 0.28 + 0.30 * breath
                  : (widget.enabled ? 0.32 : 0.08);
              final blur = _connected ? 32 + 26 * breath : 36.0;
              final spread = _connected ? 3 + 4 * breath : 3.0;

              return Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.$1.withValues(alpha: glowAlpha),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.$1.withValues(alpha: shadowAlpha),
                      blurRadius: blur,
                      spreadRadius: spread,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors.$2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.$1.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Center(
                      child: busy
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _connected
                                  ? Icons.lock_rounded
                                  : Icons.power_settings_new_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  (Color, List<Color>) _colorsFor(VpnConnectionState state) {
    return switch (state) {
      VpnConnectionState.connected => (
        AppColors.green,
        [const Color(0xFF34D399), const Color(0xFF059669)],
      ),
      VpnConnectionState.error => (
        AppColors.red,
        [const Color(0xFFF87171), const Color(0xFFDC2626)],
      ),
      _ => (AppColors.cyan, [AppColors.cyan, AppColors.purple]),
    };
  }
}
