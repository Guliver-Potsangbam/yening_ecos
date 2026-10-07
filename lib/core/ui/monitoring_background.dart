import 'package:flutter/material.dart';

/// A quiet backdrop; instrument faces retain solid surfaces for contrast.
class MonitoringBackground extends StatelessWidget {
  const MonitoringBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF101D22), Color(0xFF141D2B), Color(0xFF122821)]
              : const [Color(0xFFEEF7F4), Color(0xFFF3F6FC), Color(0xFFECF4F5)],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}
