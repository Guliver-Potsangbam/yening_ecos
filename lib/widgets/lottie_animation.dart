import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppLottieAnimation extends StatefulWidget {
  const AppLottieAnimation({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.animate = true,
    this.speed = 1.0,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool repeat;
  final bool animate;
  final double speed;

  @override
  State<AppLottieAnimation> createState() => _AppLottieAnimationState();
}

class _AppLottieAnimationState extends State<AppLottieAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      widget.asset,
      controller: _controller,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      animate: false,
      repeat: widget.repeat,
      onLoaded: (composition) {
        _controller
          ..duration = composition.duration
          ..value = 0;

        if (widget.animate) {
          if (widget.repeat) {
            _controller.repeat(
              min: 0,
              max: 1,
              period: Duration(
                milliseconds:
                    (composition.duration.inMilliseconds / widget.speed)
                        .round(),
              ),
            );
          } else {
            _controller.forward();
          }
        }
      },
    );
  }
}
