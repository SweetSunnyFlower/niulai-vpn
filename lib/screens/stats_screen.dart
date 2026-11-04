import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../services/traffic_history_store.dart';
import '../state/app_controller.dart';
import '../widgets/app_ui.dart';
import '../widgets/gradient_background.dart';
import '../widgets/traffic_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

enum _StatsRange { today, sevenDays, thirtyDays }

class _StatsScreenState extends State<StatsScreen> {
  _StatsRange _range = _StatsRange.today;
  final GlobalKey _tabStripKey = GlobalKey();
  double? _tabIndicatorLeft;
  bool _tabBarInitialized = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final now = DateTime.now();
    final start = switch (_range) {
      _StatsRange.today => DateTime(now.year, now.month, now.day),
      _StatsRange.sevenDays => now.subtract(const Duration(days: 6)),
      _StatsRange.thirtyDays => now.subtract(const Duration(days: 29)),
    };

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '流量统计',
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            _buildRangeTabBar(),
            const SizedBox(height: AppSpacing.item),
            Expanded(
              child: FutureBuilder<List<TrafficDay>>(
                future: controller.trafficHistoryStore.loadDays(start, now),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final days = _completeDays(
                    snapshot.data ?? const [],
                    start,
                    now,
                  );
                  return _StatsBody(range: _range, days: days);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setRange(_StatsRange range) {
    setState(() => _range = range);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateRangeIndicator();
      }
    });
  }

  Widget _buildRangeTabBar() {
    if (!_tabBarInitialized) {
      _tabBarInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateRangeIndicator();
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Stack(
        key: _tabStripKey,
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              for (final range in _StatsRange.values)
                Expanded(child: _buildRangeTab(range)),
            ],
          ),
          if (_tabIndicatorLeft != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              left: _tabIndicatorLeft!,
              bottom: 0,
              child: Container(
                height: 2,
                width: 24,
                decoration: BoxDecoration(
                  color: AppColors.cyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRangeTab(_StatsRange range) {
    final selected = range == _range;
    final label = switch (range) {
      _StatsRange.today => '今日',
      _StatsRange.sevenDays => '近7天',
      _StatsRange.thirtyDays => '近30天',
    };
    return InkWell(
      key: GlobalObjectKey(range),
      onTap: () => _setRange(range),
      borderRadius: BorderRadius.circular(8),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                color: selected ? AppColors.cyan : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  void _updateRangeIndicator() {
    final tabContext = GlobalObjectKey(_range).currentContext;
    final stripContext = _tabStripKey.currentContext;
    if (tabContext == null || stripContext == null) {
      return;
    }
    final tabBox = tabContext.findRenderObject() as RenderBox?;
    final stripBox = stripContext.findRenderObject() as RenderBox?;
    if (tabBox == null || stripBox == null || !mounted) {
      return;
    }
    final offset = tabBox.localToGlobal(Offset.zero, ancestor: stripBox);
    const indicatorWidth = 24.0;
    setState(() {
      _tabIndicatorLeft = offset.dx + (tabBox.size.width - indicatorWidth) / 2;
    });
  }

  List<TrafficDay> _completeDays(
    List<TrafficDay> days,
    DateTime start,
    DateTime end,
  ) {
    final byDate = <DateTime, TrafficDay>{
      for (final day in days)
        DateTime(day.date.year, day.date.month, day.date.day): day,
    };
    final result = <TrafficDay>[];
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    for (
      var date = first;
      !date.isAfter(last);
      date = date.add(const Duration(days: 1))
    ) {
      result.add(byDate[date] ?? TrafficDay(date: date));
    }
    return result;
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.range, required this.days});

  final _StatsRange range;
  final List<TrafficDay> days;

  int get upload => days.fold(0, (sum, day) => sum + day.upload);

  int get download => days.fold(0, (sum, day) => sum + day.download);

  int get duration => days.fold(0, (sum, day) => sum + day.durationSeconds);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.screenBottom,
      ),
      children: [
        SurfacePanel(
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: '上传',
                  value: Formatters.traffic(upload),
                  color: AppColors.cyan,
                ),
              ),
              Expanded(
                child: _SummaryCard(
                  label: '下载',
                  value: Formatters.traffic(download),
                  color: AppColors.green,
                ),
              ),
              Expanded(
                child: _SummaryCard(
                  label: '连接时长',
                  value: _formatDuration(duration),
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        if (range == _StatsRange.today)
          TrafficChart(samples: _todaySamples())
        else if (range == _StatsRange.thirtyDays)
          SurfacePanel(
            child: SizedBox(height: 260, child: _TrafficHeatmap(days: days)),
          )
        else
          SurfacePanel(
            child: SizedBox(height: 260, child: _DailyBarChart(days: days)),
          ),
      ],
    );
  }

  List<TrafficSample> _todaySamples() {
    final today = days.isEmpty ? null : days.last;
    final samples = <TrafficSample>[];
    if (today == null) {
      return samples;
    }
    for (var hour = 0; hour < 24; hour++) {
      final item = today.hours[hour];
      samples.add(
        TrafficSample(
          time: DateTime(
            today.date.year,
            today.date.month,
            today.date.day,
            hour,
          ),
          uploadSpeed: item?.upload ?? 0,
          downloadSpeed: item?.download ?? 0,
        ),
      );
    }
    return samples;
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h${minutes}m' : '${minutes}m';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.metric(color: color)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption()),
      ],
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.days});

  final List<TrafficDay> days;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.infinite, painter: _DailyBarPainter(days));
  }
}

class _TrafficHeatmap extends StatelessWidget {
  const _TrafficHeatmap({required this.days});

  final List<TrafficDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const SizedBox();
    }
    final maxTotal = days.fold<int>(
      0,
      (value, day) =>
          [value, day.upload + day.download].reduce((a, b) => a > b ? a : b),
    );
    final leading = days.first.date.weekday - 1;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        childAspectRatio: 1,
      ),
      itemCount: leading + days.length,
      itemBuilder: (context, index) {
        if (index < leading) {
          return const SizedBox();
        }
        final day = days[index - leading];
        return _HeatCell(day: day, maxTotal: maxTotal);
      },
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.day, required this.maxTotal});

  final TrafficDay day;
  final int maxTotal;

  @override
  Widget build(BuildContext context) {
    final total = day.upload + day.download;
    final ratio = maxTotal == 0 ? 0.0 : total / maxTotal;
    final color = AppColors.green.withValues(alpha: 0.18 + 0.72 * ratio);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          Formatters.traffic(total),
          maxLines: 1,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 7,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DailyBarPainter extends CustomPainter {
  const _DailyBarPainter(this.days);

  final List<TrafficDay> days;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty || size.isEmpty) {
      return;
    }
    const top = 10.0;
    const bottom = 24.0;
    const left = 8.0;
    const right = 8.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    if (chartWidth <= 0 || chartHeight <= 0) {
      return;
    }
    final maxValue = days.fold<int>(
      0,
      (value, day) =>
          [value, day.upload + day.download].reduce((a, b) => a > b ? a : b),
    );
    final safeMax = maxValue == 0 ? 1 : maxValue;
    final slot = chartWidth / days.length;
    final barWidth = slot * 0.48;
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final total = day.upload + day.download;
      final barHeight = chartHeight * total / safeMax;
      final uploadRatio = total == 0 ? 0.0 : day.upload / total;
      final downloadRatio = total == 0 ? 0.0 : day.download / total;
      final uploadHeight = barHeight * uploadRatio;
      final downloadHeight = barHeight * downloadRatio;
      final barLeft = left + slot * i + (slot - barWidth) / 2;
      final barTop = top + chartHeight - barHeight;
      final uploadRect = Rect.fromLTWH(barLeft, barTop, barWidth, uploadHeight);
      final downloadRect = Rect.fromLTWH(
        barLeft,
        barTop + uploadHeight,
        barWidth,
        downloadHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(uploadRect, const Radius.circular(4)),
        Paint()..color = AppColors.cyan,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(downloadRect, const Radius.circular(4)),
        Paint()..color = AppColors.green,
      );
    }

    final labelIndexes = _labelIndexes(days.length);
    for (final index in labelIndexes) {
      final date = days[index].date;
      final label = '${date.month}/${date.day}';
      final painter = _layoutLabel(label, fontSize: days.length > 20 ? 8 : 9);
      final x = left + slot * index + slot / 2 - painter.width / 2;
      final clampedX = x.clamp(0.0, size.width - painter.width).toDouble();
      painter.paint(canvas, Offset(clampedX, size.height - painter.height));
    }
  }

  List<int> _labelIndexes(int count) {
    return List<int>.generate(count, (index) => index);
  }

  TextPainter _layoutLabel(String text, {required double fontSize}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: AppColors.textSecondary, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _DailyBarPainter oldDelegate) =>
      oldDelegate.days != days;
}
