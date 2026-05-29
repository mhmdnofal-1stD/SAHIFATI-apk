import 'package:flutter/material.dart';

import '../../core/utils/size_config.dart';
import 'pending_sync_banner.dart';
import 'soft_pattern_background.dart';

class ResponsiveContentShell extends StatelessWidget {
  const ResponsiveContentShell({
    super.key,
    this.child,
    this.builder,
    this.maxContentWidth = 1120,
    this.horizontalGutter,
    this.pendingSyncBottomPadding = 16,
  }) : assert(child != null || builder != null);

  final Widget? child;
  final WidgetBuilder? builder;
  final double maxContentWidth;
  final double? horizontalGutter;
  final double pendingSyncBottomPadding;

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
        final gutter = horizontalGutter ?? _horizontalGutter(viewportWidth);
        final availableWidth =
            (viewportWidth - (gutter * 2)).clamp(0.0, double.infinity);
        final contentWidth = availableWidth > maxContentWidth
            ? maxContentWidth
            : availableWidth;
        final centeredHorizontalPadding =
          gutter + ((availableWidth - contentWidth) / 2);
        final boundedHeight = viewportConstraints.hasBoundedHeight
            ? viewportConstraints.maxHeight
            : MediaQuery.sizeOf(context).height;

        return SoftPatternBackground(
          child: SizedBox(
          width: double.infinity,
          height: boundedHeight,
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: centeredHorizontalPadding),
            child: SizedBox(
              width: contentWidth,
              height: boundedHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PendingSyncBanner(bottomPadding: pendingSyncBottomPadding),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        SizeConfig().initWithConstraints(
                          context,
                          BoxConstraints(
                            maxWidth: contentWidth,
                            maxHeight: boundedHeight,
                          ),
                        );
                        return builder?.call(context) ?? child!;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}
