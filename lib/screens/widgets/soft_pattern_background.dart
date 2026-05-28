import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sahifaty/core/constants/assets.dart';

class SoftPatternBackground extends StatelessWidget {
  final Widget child;
  final double patternOpacity;
  final int topOverlayAlpha;
  final int bottomOverlayAlpha;

  const SoftPatternBackground({
    super.key,
    required this.child,
    this.patternOpacity = 0.58,
    this.topOverlayAlpha = 8,
    this.bottomOverlayAlpha = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: patternOpacity,
              child: SvgPicture.asset(
                Assets.softPatternBackgroundSvg,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha(topOverlayAlpha),
                    Colors.white.withAlpha(bottomOverlayAlpha),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}