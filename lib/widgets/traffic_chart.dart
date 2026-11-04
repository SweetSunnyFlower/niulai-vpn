import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../state/app_controller.dart';
import 'app_ui.dart';

class TrafficChart extends StatelessWidget {
  const TrafficChart({super.key, required this.samples, this.onTap});

  final List<TrafficSample> samples;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final maxSpeed = samples.fold<int>(
      0,
      (max, sample) =>
          math.max(max, math.max(sample.uploadSpeed, sample.downloadSpeed)),
    );
    return SurfacePanel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              const _LegendDot(color: AppColors.cyan, label: '上传'),
              const SizedBox(width: 18),
              const _LegendDot(color: AppColors.green, label: '下载'),
              const Spacer(),
              Text(
                '峰值 ${Formatters.speed(maxSpeed)}',
                style: AppTextStyles.caption(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: samples.isEmpty
                ? const Center(
                    child: Text(
                      '暂无流量数据',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: _TrafficChartPainter(samples: samples),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption()),
      ],
    );
  }
}

class _TrafficChartPainter extends CustomPainter {
  const _TrafficChartPainter({required this.samples});

  final List<TrafficSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final left = 10.0;
    final right = 10.0;
    final top = 14.0;
    final bottom = 24.0;
    final plotWidth = size.width - left - right;
    final plotHeight = size.height - top - bottom;
    if (plotWidth <= 0 || plotHeight <= 0) {
      return;
    }

    final gridPaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = top + plotHeight * i / gridLines;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    final maxSpeed = samples.fold<int>(
      0,
      (max, sample) =>
          math.max(max, math.max(sample.uploadSpeed, sample.downloadSpeed)),
    );
    final scaleMax = math.max(1, maxSpeed).toDouble();

    Offset pointAt(int index, int speed) {
      final x = samples.length == 1
          ? left + plotWidth / 2
          : left + plotWidth * index / (samples.length - 1);
      final y = top + plotHeight * (1 - speed / scaleMax);
      return Offset(x, y);
    }

    _drawLine(
      canvas,
      samples,
      (sample) => pointAt(samples.indexOf(sample), sample.uploadSpeed),
      AppColors.cyan,
    );
    _drawLine(
      canvas,
      samples,
      (sample) => pointAt(samples.indexOf(sample), sample.downloadSpeed),
      AppColors.green,
    );

    if (samples.length > 1) {
      final indices = <int>{0, samples.length ~/ 2, samples.length - 1}.toList()
        ..sort();
      for (final index in indices) {
        final label = _formatTime(samples[index].time);
        final textPainter = _layoutLabel(
          label,
          color: AppColors.textSecondary,
          fontSize: 9,
        );
        final x = left + plotWidth * index / (samples.length - 1);
        final offset = Offset(
          (x - textPainter.width / 2)
              .clamp(0, size.width - textPainter.width)
              .toDouble(),
          size.height - textPainter.height,
        );
        textPainter.paint(canvas, offset);
      }
    }
  }

  void _drawLine(
    Canvas canvas,
    List<TrafficSample> data,
    Offset Function(TrafficSample sample) toPoint,
    Color color,
  ) {
    if (data.isEmpty) {
      return;
    }
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final point = toPoint(data[i]);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  TextPainter _layoutLabel(
    String text, {
    required Color color,
    required double fontSize,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  @override
  bool shouldRepaint(covariant _TrafficChartPainter oldDelegate) {
    return oldDelegate.samples != samples;
  }
}
