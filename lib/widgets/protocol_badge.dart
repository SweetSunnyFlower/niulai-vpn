import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/proxy_node.dart';

class ProtocolBadge extends StatelessWidget {
  const ProtocolBadge({super.key, required this.protocol});

  final ProxyProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(protocol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Text(
        protocol.label,
        style: AppTextStyles.caption(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  static Color colorFor(ProxyProtocol protocol) {
    return switch (protocol) {
      ProxyProtocol.vless => AppColors.cyan,
      ProxyProtocol.vmess => AppColors.purple,
      ProxyProtocol.trojan => AppColors.amber,
      ProxyProtocol.shadowsocks => const Color(0xFF4ADE80),
      ProxyProtocol.socks => const Color(0xFFF472B6),
      ProxyProtocol.ssr => const Color(0xFFA78BFA),
      ProxyProtocol.hysteria2 => const Color(0xFFFB7185),
      ProxyProtocol.tuic => const Color(0xFF60A5FA),
      ProxyProtocol.unknown => AppColors.textSecondary,
    };
  }
}
