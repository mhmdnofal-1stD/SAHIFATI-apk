import 'package:flutter/material.dart';

import '../../core/utils/size_config.dart';

class ResponsiveContentShell extends StatelessWidget {
  const ResponsiveContentShell({
    super.key,
    required this.child,
    this.maxContentWidth = 1120,
  });

  final Widget child;
  final double maxContentWidth;

  double _horizontalGutter(double viewportWidth) {
    if (viewportWidth >= 1400) {
      return 56;
    }
    if (viewportWidth >= 1024) {
      return 40;
    }
    if (viewportWidth >= 700) {
      return 24;
    }
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        final viewportWidth = viewportConstraints.maxWidth;
        final gutter = _horizontalGutter(viewportWidth);
        final availableWidth = (viewportWidth - (gutter * 2)).clamp(0.0, double.infinity);
        final contentWidth = availableWidth > maxContentWidth
            ? maxContentWidth
            : availableWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: LayoutBuilder(
                builder: (context, contentConstraints) {
                  SizeConfig().initWithConstraints(context, contentConstraints);
                  return child;
                },
              ),
            ),
          ),
        );
      },
    );
  }
}