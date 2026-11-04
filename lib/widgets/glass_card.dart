import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.card),
    this.onTap,
    this.borderRadius = AppRadii.card,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlight
                  ? [
                      AppColors.surfaceLight.withValues(alpha: 0.72),
                      AppColors.surface.withValues(alpha: 0.56),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.09),
                      Colors.white.withValues(alpha: 0.035),
                    ],
            ),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              if (highlight)
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      ),
    );
  }
}
