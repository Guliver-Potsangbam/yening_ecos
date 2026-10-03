import 'package:flutter/material.dart';

import 'lottie_animation.dart';

class DeviceConnectingAnimation extends StatelessWidget {
  const DeviceConnectingAnimation({super.key, this.size = 180});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppLottieAnimation(
      asset: 'assets/animations/device_connecting.json',
      width: size,
      height: size,
      repeat: true,
    );
  }
}
