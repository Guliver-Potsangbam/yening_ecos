import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  });

  final String label;
  final double? value;
  final String unit;
  final double minimum;
  final double maximum;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actual = value;
    final progress = actual == null
        ? 0.0
        : ((actual - minimum) / (maximum - minimum)).clamp(0.0, 1.0);
    return Semantics(
      label: actual == null
          ? '$label: no reading'
          : '$label: ${actual.toStringAsFixed(1)} $unit',
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: 160,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, animated, _) => CustomPaint(
                  painter: _GaugePainter(
                    progress: animated,
                    color: color,
                    track: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          actual == null
                              ? '—'
                              : '${actual.toStringAsFixed(1)}$unit',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${minimum.toStringAsFixed(0)}$unit',
                    style: theme.textTheme.labelSmall,
                  ),
                  Text(
                    '${maximum.toStringAsFixed(0)}$unit',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actual != null && (actual < minimum || actual > maximum))
              Text('Outside sensor range', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.progress,
    required this.color,
    required this.track,
  });
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2 - 10;
    if (radius <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final bounds = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi * 5 / 6;
    const sweep = math.pi * 4 / 3;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(bounds, start, sweep, false, paint);
    if (progress > 0) {
      paint.color = color;
      canvas.drawArc(bounds, start, sweep * progress, false, paint);
      final angle = start + sweep * progress;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        6,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      track != oldDelegate.track;
}
