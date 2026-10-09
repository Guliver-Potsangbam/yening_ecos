import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/local_time_format.dart';
import '../models/telemetry_target_range.dart';

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
    this.subtitle,
    this.explanation,
    this.semanticUnit,
    this.targetRange,
    this.targetControl,
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
  final String? subtitle;
  final String? explanation;
  final String? semanticUnit;
  final TelemetryTargetRange? targetRange;
  final Widget? targetControl;
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
  double get _low =>
      targetRange?.minimum ?? lowThreshold ?? minimum + (maximum - minimum) / 3;
  double get _high =>
      targetRange?.maximum ??
      highThreshold ??
      minimum + (maximum - minimum) * 2 / 3;
  double get _lowProgress => (_low - minimum) / (maximum - minimum);
  double get _highProgress => (_high - minimum) / (maximum - minimum);

  bool get _offline => freshnessLabel == 'Offline';

  Color get readingColor {
    if (_offline) return const Color(0xFF757575);
    final actual = _reading;
    if (targetRange != null && actual != null) {
      if (freshnessLabel != 'Live') return const Color(0xFF64748B);
      return targetRange!.position(actual) == TargetPosition.within
          ? color
          : highColor;
    }
    if (actual == null || actual <= _low) return lowColor;
    return actual <= _high ? color : highColor;
  }

  String get _level {
    final actual = _reading;
    if (actual == null) return 'No reading';
    if (_offline) return 'Last reading';
    if (actual < minimum || actual > maximum) return 'Outside sensor range';
    if (targetRange != null) {
      if (freshnessLabel != 'Live') return 'Target check paused';
      return switch (targetRange!.position(actual)) {
        TargetPosition.below => 'Below target',
        TargetPosition.within => 'Within target',
        TargetPosition.above => 'Above target',
      };
    }
    if (statusLabel != null) return statusLabel!;
    if (actual <= _low) return 'Low';
    return actual <= _high ? 'Medium' : 'High';
  }

  void _showInformation(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'About $label',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close information',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(explanation!),
              const SizedBox(height: 16),
              Text('Dial scale', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '${minimum.toStringAsFixed(0)}–${maximum.toStringAsFixed(0)} $unit. Without a target, color bands indicate magnitude. With a target, the green band marks your chosen range.',
              ),
              if (targetControl != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Your target range',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap the target row to choose or change the limits for this environment. A live reading shows whether it is inside your range and its distance from the closest boundary. Checks pause when readings are stale or offline.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Humidity and brightness differences use percentage points (pp): 60% to 62% is 2 pp.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Theme.of(context);
    final dark = appTheme.brightness == Brightness.dark;
    // A neutral local palette greys the entire card, including controls. It
    // keeps full contrast and interaction rather than fading the subtree.
    final offlineText = dark
        ? const Color(0xFFBFC3C7)
        : const Color(0xFF555B60);
    final offlineScheme = appTheme.colorScheme.copyWith(
      primary: dark ? const Color(0xFFBFC3C7) : const Color(0xFF656B70),
      onSurface: offlineText,
      onSurfaceVariant: dark
          ? const Color(0xFFB0B5BA)
          : const Color(0xFF60666C),
      surface: dark ? const Color(0xFF252629) : const Color(0xFFE8EAED),
      surfaceContainerLow: dark
          ? const Color(0xFF252629)
          : const Color(0xFFE8EAED),
      surfaceContainerLowest: dark
          ? const Color(0xFF202124)
          : const Color(0xFFF1F2F3),
      outline: dark ? const Color(0xFF8F9499) : const Color(0xFF858A8F),
      outlineVariant: dark ? const Color(0xFF55595D) : const Color(0xFFBDC2C7),
    );
    final theme = _offline
        ? appTheme.copyWith(
            colorScheme: offlineScheme,
            textTheme: appTheme.textTheme.apply(
              bodyColor: offlineText,
              displayColor: offlineText,
            ),
          )
        : appTheme;
    final scheme = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final dialHeight = (horizontal ? 100 : 116) * scale.clamp(1.0, 2.0);
    final actual = _reading;
    final accent = _offline
        ? (dark ? const Color(0xFFB0B5BA) : const Color(0xFF757575))
        : actual == null
        ? scheme.onSurfaceVariant
        : readingColor;
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
        : freshnessLabel == 'Stale' || _offline
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
            lowColor: _offline
                ? scheme.outline
                : targetRange == null
                ? lowColor
                : highColor,
            mediumColor: _offline ? scheme.outline : color,
            highColor: _offline ? scheme.outline : highColor,
            needleColor: accent,
            faceColor: _offline ? scheme.surfaceContainerLow : scheme.surface,
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
                    color: _offline
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
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
    final freshness = Container(
      key: ValueKey('metric-freshness-$label'),
      padding: _offline
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
          : EdgeInsets.zero,
      decoration: _offline
          ? BoxDecoration(
              color: freshnessColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            freshnessLabel == 'Live'
                ? Icons.radio_button_checked_rounded
                : _offline
                ? Icons.wifi_off_rounded
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
      ),
    );
    final timestamp = Text(
      updatedAt == null
          ? 'Awaiting update'
          : '${_offline ? 'Last updated' : 'Updated'} ${formatLocalTime12(updatedAt!)}',
      key: updatedAtKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontSize: 11,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return Theme(
      data: theme,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: actual == null
            ? '$label: no reading${_offline ? ', Offline' : ''}'
            : '$label: ${actual.toStringAsFixed(1)} ${semanticUnit ?? unit}${_offline
                  ? ', Offline, last reading'
                  : targetRange != null
                  ? ', $_level'
                  : statusLabel == null
                  ? ''
                  : ', $statusLabel'}',
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Every meter reserves the same slots, including the temperature unit
            // control and timestamp, so different labels never change card height.
            final stackedHeader = constraints.maxWidth - 24 < 220 * scale;
            final headingHeight = stackedHeader ? 104 * scale : 48 * scale;
            final headingText = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 17, color: accent),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: stackedHeader ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (explanation != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            );
            final heading = explanation == null
                ? ExcludeSemantics(child: headingText)
                : Semantics(
                    button: true,
                    label: 'About $label',
                    onTap: () => _showInformation(context),
                    excludeSemantics: true,
                    child: InkWell(
                      key: ValueKey('metric-information-$label'),
                      onTap: () => _showInformation(context),
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: 48 * scale),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          heightFactor: 1,
                          child: headingText,
                        ),
                      ),
                    ),
                  );
            final footer = Tooltip(
              message: updatedAt == null
                  ? 'No sensor update received'
                  : formatLocalDateTime12(updatedAt!),
              child: timestamp,
            );
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _offline
                      ? scheme.surfaceContainerLow
                      : scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: dark ? 0.08 : 0.025,
                      ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  heading,
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
                                  Expanded(child: heading),
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
                      if (targetControl != null) ...[
                        const SizedBox(height: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ),
                          child: targetControl!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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
      final segmentSweep = sweep * (ends[band + 1] - ends[band]);
      if (segmentSweep <= 0) continue;
      final gap = math.min(0.015, segmentSweep / 4);
      canvas.drawArc(
        bounds,
        start + sweep * ends[band] + gap,
        segmentSweep - gap * 2,
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
