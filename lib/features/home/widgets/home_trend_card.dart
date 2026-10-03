import 'dart:math' as math;

import 'package:flutter/material.dart';

class HomeTrendCard extends StatelessWidget {
  const HomeTrendCard({
    super.key,
    required this.deviceTypeId,
    required this.chartData,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  final String deviceTypeId;
  final Map<String, List<double>> chartData;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  List<double> get _selectedChartData {
    return chartData['${deviceTypeId}_$selectedRange'] ??
        const [0, 0, 0, 0, 0, 0, 0];
  }

  String get _trendTitle {
    switch (deviceTypeId) {
      case 'watersense':
        return 'Water pH';

      case 'gaschecker':
        return 'CO₂ Level';

      case 'envirosense':
      default:
        return 'Temperature';
    }
  }

  String get _trendValue {
    final data = _selectedChartData;

    if (data.isEmpty) {
      return '--';
    }

    final value = data.last;

    switch (deviceTypeId) {
      case 'watersense':
        return value.toStringAsFixed(1);

      case 'gaschecker':
        return value.round().toString();

      case 'envirosense':
      default:
        return value.toStringAsFixed(1);
    }
  }

  String get _trendUnit {
    switch (deviceTypeId) {
      case 'watersense':
        return 'pH';

      case 'gaschecker':
        return 'ppm';

      case 'envirosense':
      default:
        return '°C';
    }
  }

  double? get _trendChangePercentage {
    final data = _selectedChartData;

    if (data.length < 2 || data.first == 0) {
      return null;
    }

    final difference = data.last - data.first;

    return (difference / data.first.abs()) * 100;
  }

  String get _trendChange {
    final percentage = _trendChangePercentage;

    if (percentage == null) {
      return '--';
    }

    final sign = percentage >= 0 ? '+' : '';

    return '$sign${percentage.toStringAsFixed(1)}%';
  }

  String get _rangeStartLabel {
    switch (selectedRange) {
      case '7D':
        return '7 days ago';

      case '30D':
        return '30 days ago';

      case '24H':
      default:
        return '24 hours ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _selectedChartData;
    final change = _trendChangePercentage;
    final isIncrease = change != null && change >= 0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _trendTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _trendValue,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(width: 5),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              _trendUnit,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (change != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isIncrease
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _trendChange,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendChartPainter(
                  data: data,
                  brightness: Theme.of(context).brightness,
                  accentColor: Theme.of(context).colorScheme.primary,
                  textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  _rangeStartLabel,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                Text('Now', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '24H', label: Text('24H')),
                  ButtonSegment(value: '7D', label: Text('7D')),
                  ButtonSegment(value: '30D', label: Text('30D')),
                ],
                selected: {selectedRange},
                onSelectionChanged: (selection) {
                  onRangeChanged(selection.first);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.data,
    required this.brightness,
    required this.accentColor,
    required this.textColor,
  });

  final List<double> data;
  final Brightness brightness;
  final Color accentColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }

    const chartTop = 8.0;
    const chartBottom = 26.0;
    const chartLeft = 4.0;
    const chartRight = 4.0;

    final chartRect = Rect.fromLTRB(
      chartLeft,
      chartTop,
      size.width - chartRight,
      size.height - chartBottom,
    );

    final minData = data.reduce(math.min);
    final maxData = data.reduce(math.max);

    final rawRange = maxData - minData;

    final padding = rawRange == 0
        ? math.max(maxData.abs() * 0.05, 1)
        : rawRange * 0.16;

    final minValue = minData - padding;
    final maxValue = maxData + padding;
    final valueRange = maxValue - minValue;

    final gridColor = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    final axisColor = brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.28);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = brightness == Brightness.dark ? Colors.black : Colors.white
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.16),
          accentColor.withValues(alpha: 0.015),
        ],
      ).createShader(chartRect);

    const horizontalLines = 4;

    for (int i = 0; i <= horizontalLines; i++) {
      final fraction = i / horizontalLines;
      final y = chartRect.top + chartRect.height * fraction;

      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    const verticalLines = 6;

    for (int i = 0; i < verticalLines; i++) {
      final fraction = i / (verticalLines - 1);
      final x = chartRect.left + chartRect.width * fraction;

      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        gridPaint,
      );
    }

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = data.length == 1
          ? chartRect.center.dx
          : chartRect.left + (i / (data.length - 1)) * chartRect.width;

      final normalized = (data[i] - minValue) / valueRange;

      final y = chartRect.bottom - normalized * chartRect.height;

      points.add(Offset(x, y));
    }

    if (points.length == 1) {
      final point = points.first;

      canvas.drawCircle(point, 7, pointBorderPaint);

      canvas.drawCircle(point, 4, pointPaint);

      return;
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      final controlPoint1 = Offset(
        current.dx + (next.dx - current.dx) * 0.45,
        current.dy,
      );

      final controlPoint2 = Offset(
        next.dx - (next.dx - current.dx) * 0.45,
        next.dy,
      );

      linePath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        next.dx,
        next.dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartRect.bottom)
      ..lineTo(points.first.dx, chartRect.bottom)
      ..close();

    canvas.drawPath(fillPath, fillPaint);

    canvas.drawPath(linePath, linePaint);

    final lastPoint = points.last;

    canvas.drawCircle(lastPoint, 7, pointBorderPaint);

    canvas.drawCircle(lastPoint, 4, pointPaint);

    final guidePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(lastPoint.dx, chartRect.top),
      Offset(lastPoint.dx, lastPoint.dy - 6),
      guidePaint,
    );

    final textStyle = TextStyle(
      color: textColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final topPainter = TextPainter(
      text: TextSpan(text: _formatChartValue(maxData), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final bottomPainter = TextPainter(
      text: TextSpan(text: _formatChartValue(minData), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    topPainter.paint(
      canvas,
      Offset(chartRect.right - topPainter.width, chartRect.top - 2),
    );

    bottomPainter.paint(
      canvas,
      Offset(
        chartRect.right - bottomPainter.width,
        chartRect.bottom - bottomPainter.height + 2,
      ),
    );
  }

  String _formatChartValue(double value) {
    if (value.abs() >= 100) {
      return value.round().toString();
    }

    return value.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.brightness != brightness ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.textColor != textColor;
  }
}
