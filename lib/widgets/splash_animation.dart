import 'package:flutter/material.dart';

import 'lottie_animation.dart';

class SplashAnimation extends StatelessWidget {
  const SplashAnimation({super.key, this.size = 180});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppLottieAnimation(
      asset: 'assets/animations/splash.json',
      width: size,
      height: size,
      repeat: true,
      speed: 0.7,
    );
  }
}
