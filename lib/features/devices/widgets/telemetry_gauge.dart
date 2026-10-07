import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact instrument dial. Bands indicate magnitude, not alert limits.
class TelemetryGauge extends StatelessWidget {
  const TelemetryGauge({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.minimum,
    required this.maximum,
    required this.color,
    required this.icon,
    this.statusLabel,
    this.lowThreshold,
    this.highThreshold,
    this.lowColor = const Color(0xFF4189BD),
    this.highColor = const Color(0xFFD98536),
    this.trailing,
    this.horizontal = false,
  }) : assert(minimum < maximum),
       assert(
         lowThreshold == null ||
             (lowThreshold > minimum && lowThreshold < maximum),
       ),
       assert(
         highThreshold == null ||
             (highThreshold > minimum && highThreshold < maximum),
       ),
       assert(
         lowThreshold == null ||
             highThreshold == null ||
             lowThreshold < highThreshold,
       );

  final String label;
  final double? value;
  final String unit;
  final double minimum;
  final double maximum;
  final Color color;
  final IconData icon;
  final String? statusLabel;
  final double? lowThreshold;
  final double? highThreshold;
  final Color lowColor;
  final Color highColor;
  final Widget? trailing;
  final bool horizontal;

  double? get _reading => value?.isFinite == true ? value : null;
  double get _low => lowThreshold ?? minimum + (maximum - minimum) / 3;
  double get _high => highThreshold ?? minimum + (maximum - minimum) * 2 / 3;
  double get _lowProgress => (_low - minimum) / (maximum - minimum);
  double get _highProgress => (_high - minimum) / (maximum - minimum);

  Color get readingColor {
    final actual = _reading;
    if (actual == null || actual <= _low) return lowColor;
    return actual <= _high ? color : highColor;
  }

  String get _level {
    final actual = _reading;
    if (actual == null) return 'No reading';
    if (actual < minimum || actual > maximum) return 'Outside sensor range';
    if (statusLabel != null) return statusLabel!;
    if (actual <= _low) return 'Low';
    return actual <= _high ? 'Medium' : 'High';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dialHeight =
        128 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final actual = _reading;
    final accent = actual == null ? scheme.onSurfaceVariant : readingColor;
    final statusColor = Color.lerp(
      accent,
      scheme.brightness == Brightness.dark ? Colors.white : Colors.black,
      scheme.brightness == Brightness.dark ? 0.3 : 0.2,
    )!;
    final progress = actual == null
        ? 0.0
        : ((actual - minimum) / (maximum - minimum)).clamp(0.0, 1.0);

    Widget dial() => SizedBox(
      height: dialHeight,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => CustomPaint(
          painter: _InstrumentDialPainter(
            progress: animated,
            hasReading: actual != null,
            lowProgress: _lowProgress,
            highProgress: _highProgress,
            lowColor: lowColor,
            mediumColor: color,
            highColor: highColor,
            needleColor: accent,
            faceColor: scheme.surface,
            tickColor: scheme.onSurfaceVariant,
            rimColor: scheme.outlineVariant,
            minimum: minimum,
            maximum: maximum,
            labelStyle: theme.textTheme.labelSmall!.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          child: Align(
            alignment: const Alignment(0, 0.67),
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  actual == null ? '—' : '${actual.toStringAsFixed(1)}$unit',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final status = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _level,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: actual == null
          ? '$label: no reading'
          : '$label: ${actual.toStringAsFixed(1)} $unit${statusLabel == null ? '' : ', $statusLabel'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ExcludeSemantics(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 16, color: accent),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  label,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ),
              ExcludeSemantics(
                child: horizontal
                    ? LayoutBuilder(
                        builder: (context, constraints) => Row(
                          children: [
                            SizedBox(
                              width: math.min(156, constraints.maxWidth * 0.5),
                              child: dial(),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  status,
                                  const SizedBox(height: 12),
                                  _RangeLegend(
                                    color: lowColor,
                                    label: 'Low',
                                    bound: '≤${_low.toStringAsFixed(0)}$unit',
                                  ),
                                  const SizedBox(height: 7),
                                  _RangeLegend(
                                    color: color,
                                    label: 'Medium',
                                    bound:
                                        '${_low.toStringAsFixed(0)}–${_high.toStringAsFixed(0)}$unit',
                                  ),
                                  const SizedBox(height: 7),
                                  _RangeLegend(
                                    color: highColor,
                                    label: 'High',
                                    bound: '>${_high.toStringAsFixed(0)}$unit',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          dial(),
                          Center(child: status),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeLegend extends StatelessWidget {
  const _RangeLegend({
    required this.color,
    required this.label,
    required this.bound,
  });
  final Color color;
  final String label;
  final String bound;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
      Text(
        bound,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class _InstrumentDialPainter extends CustomPainter {
  const _InstrumentDialPainter({
    required this.progress,
    required this.hasReading,
    required this.lowProgress,
    required this.highProgress,
    required this.lowColor,
    required this.mediumColor,
    required this.highColor,
    required this.needleColor,
    required this.faceColor,
    required this.tickColor,
    required this.rimColor,
    required this.minimum,
    required this.maximum,
    required this.labelStyle,
  });
  final double progress;
  final bool hasReading;
  final double lowProgress;
  final double highProgress;
  final Color lowColor;
  final Color mediumColor;
  final Color highColor;
  final Color needleColor;
  final Color faceColor;
  final Color tickColor;
  final Color rimColor;
  final double minimum;
  final double maximum;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width * 0.45, size.height * 0.43);
    if (radius <= 10) return;
    final center = Offset(size.width / 2, size.height * 0.49);
    final bounds = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi * 8 / 9;
    const sweep = math.pi * 11 / 9;
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()..color = rimColor.withValues(alpha: 0.12),
    );
    canvas.drawCircle(center, radius + 2, Paint()..color = faceColor);

    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.butt;
    final ends = [0.0, lowProgress, highProgress, 1.0];
    final colors = [lowColor, mediumColor, highColor];
    for (var band = 0; band < 3; band++) {
      bandPaint.color = colors[band].withValues(alpha: hasReading ? 0.8 : 0.22);
      canvas.drawArc(
        bounds,
        start + sweep * ends[band] + 0.015,
        sweep * (ends[band + 1] - ends[band]) - 0.03,
        false,
        bandPaint,
      );
    }
    for (var tick = 0; tick <= 20; tick++) {
      final position = tick / 20;
      final angle = start + sweep * position;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final major = tick % 5 == 0;
      canvas.drawLine(
        center + direction * (radius - 6),
        center + direction * (radius - (major ? 13 : 10)),
        Paint()
          ..color = tickColor.withValues(alpha: major ? 0.8 : 0.4)
          ..strokeWidth = major ? 1.4 : 0.8,
      );
      if (major) {
        final label = TextPainter(
          text: TextSpan(
            text: (minimum + (maximum - minimum) * position).toStringAsFixed(0),
            style: labelStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final location = center + direction * (radius - 23);
        label.paint(
          canvas,
          location - Offset(label.width / 2, label.height / 2),
        );
      }
    }
    if (!hasReading) return;
    final angle = start + sweep * progress;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final perpendicular = Offset(-direction.dy, direction.dx);
    final needle = Path()
      ..moveTo(
        (center + perpendicular * 2.3).dx,
        (center + perpendicular * 2.3).dy,
      )
      ..lineTo(
        (center + direction * (radius - 14)).dx,
        (center + direction * (radius - 14)).dy,
      )
      ..lineTo(
        (center - perpendicular * 2.3).dx,
        (center - perpendicular * 2.3).dy,
      )
      ..lineTo((center - direction * 7).dx, (center - direction * 7).dy)
      ..close();
    canvas.drawPath(
      needle.shift(const Offset(0, 1.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawPath(needle, Paint()..color = needleColor);
    canvas.drawCircle(center, 4.7, Paint()..color = needleColor);
    canvas.drawCircle(center, 2, Paint()..color = faceColor);
  }

  @override
  bool shouldRepaint(_InstrumentDialPainter old) =>
      progress != old.progress ||
      hasReading != old.hasReading ||
      lowProgress != old.lowProgress ||
      highProgress != old.highProgress ||
      lowColor != old.lowColor ||
      mediumColor != old.mediumColor ||
      highColor != old.highColor ||
      needleColor != old.needleColor ||
      faceColor != old.faceColor ||
      tickColor != old.tickColor ||
      rimColor != old.rimColor ||
      minimum != old.minimum ||
      maximum != old.maximum ||
      labelStyle != old.labelStyle;
}
