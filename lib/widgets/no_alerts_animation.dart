import 'package:flutter/material.dart';

import 'lottie_animation.dart';

class NoAlertsAnimation extends StatelessWidget {
  const NoAlertsAnimation({super.key, this.size = 150});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppLottieAnimation(
      asset: 'assets/animations/no_alerts.json',
      width: size,
      height: size,
      repeat: true,
    );
  }
}
