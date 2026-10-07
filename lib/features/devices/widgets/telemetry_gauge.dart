import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/local_time_format.dart';

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
    this.updatedAt,
    this.updatedAtKey,
    this.freshnessLabel,
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
  final DateTime? updatedAt;
  final Key? updatedAtKey;
  final String? freshnessLabel;

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
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final dialHeight = (horizontal ? 100 : 116) * scale.clamp(1.0, 2.0);
    final actual = _reading;
    final accent = actual == null ? scheme.onSurfaceVariant : readingColor;
    final dark = scheme.brightness == Brightness.dark;
    final statusColor = Color.lerp(
      accent,
      dark ? Colors.white : Colors.black,
      dark ? 0.3 : 0.2,
    )!;
    final progress = actual == null
        ? 0.0
        : ((actual - minimum) / (maximum - minimum)).clamp(0.0, 1.0);
    final freshnessColor = freshnessLabel == 'Live'
        ? (dark ? const Color(0xFF79DCCB) : const Color(0xFF176D60))
        : freshnessLabel == 'Stale'
        ? (dark ? const Color(0xFFF1C179) : const Color(0xFF8D5A16))
        : scheme.onSurfaceVariant;

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
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
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

    final level = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _level,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final freshness = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          freshnessLabel == 'Live'
              ? Icons.radio_button_checked_rounded
              : Icons.schedule_rounded,
          size: 12,
          color: freshnessColor,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            freshnessLabel ?? 'Waiting',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: freshnessColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    final timestamp = Text(
      updatedAt == null
          ? 'Awaiting update'
          : 'Updated ${formatLocalTime12(updatedAt!)}',
      key: updatedAtKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontSize: 11,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: actual == null
          ? '$label: no reading'
          : '$label: ${actual.toStringAsFixed(1)} $unit${statusLabel == null ? '' : ', $statusLabel'}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Every meter reserves the same slots, including the temperature unit
          // control and timestamp, so different labels never change card height.
          final stackedHeader = constraints.maxWidth - 24 < 220 * scale;
          final headingHeight = stackedHeader ? 88 * scale : 48 * scale;
          final heading = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
          final footer = Tooltip(
            message: updatedAt == null
                ? 'No sensor update received'
                : formatLocalDateTime12(updatedAt!),
            child: timestamp,
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.08 : 0.025),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, horizontal ? 8 : 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: headingHeight,
                    child: stackedHeader
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ExcludeSemantics(child: heading),
                              SizedBox(
                                height: 48 * scale,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: trailing,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: ExcludeSemantics(child: heading)),
                              if (trailing != null) ...[
                                const SizedBox(width: 6),
                                trailing!,
                              ],
                            ],
                          ),
                  ),
                  if (horizontal)
                    Row(
                      children: [
                        SizedBox(
                          width: math.min(
                            144 * scale,
                            (constraints.maxWidth - 34) * 0.5,
                          ),
                          child: ExcludeSemantics(child: dial()),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: dialHeight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ExcludeSemantics(child: level),
                                const SizedBox(height: 12),
                                freshness,
                                const SizedBox(height: 6),
                                footer,
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    ExcludeSemantics(child: dial()),
                    SizedBox(
                      height: 30 * scale,
                      child: Center(child: ExcludeSemantics(child: level)),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 22 * scale,
                      child: Center(child: freshness),
                    ),
                    SizedBox(
                      height: 22 * scale,
                      child: Center(child: footer),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
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
