import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class SizeConfig {
  static const double _mobileDesignWidth = 375.0;
  static const double _mobileDesignHeight = 812.0;
  static double? screenWidth;
  static double? screenHeight;
  static double? defaultSize;
  static Orientation? orientation;

  void init(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    initWithConstraints(
      context,
      BoxConstraints(
        maxWidth: mediaQuery.size.width,
        maxHeight: mediaQuery.size.height,
      ),
    );
  }

  void initWithConstraints(BuildContext context, BoxConstraints constraints) {
    final mediaQuery = MediaQuery.of(context);
    final constrainedWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : mediaQuery.size.width;
    final constrainedHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : mediaQuery.size.height;

    screenWidth = constrainedWidth;
    screenHeight = constrainedHeight;
    orientation = constrainedWidth >= constrainedHeight
        ? Orientation.landscape
        : Orientation.portrait;
    defaultSize = orientation == Orientation.landscape
        ? screenHeight! * .024
        : screenWidth! * .024;

    if (kDebugMode) {
      print('this is the default size $defaultSize');
    }
  }

  // static double getProportionalWidth(double width) {
  //   //2.4 is the factor
  //   width = (width * 2.4) / 100;
  //   return (width / defaultSize!) * screenWidth!;
  // }
  //
  // static double getProportionalHeight(double height) {
  //   //1.09 is the factor
  //   height = (height * 1.09) / 100;
  //   return (height / defaultSize!) * screenHeight!;
  // }

  static double getProportionalWidth(double inputWidth) {
    return (inputWidth / _mobileDesignWidth) * screenWidth!;
  }

  static double getProportionalHeight(double inputHeight) {
    return (inputHeight / _mobileDesignHeight) * screenHeight!;
  }

  static double getProperVerticalSpace(double value) {
    var space = screenHeight! / value;
    return space;
  }

  static double getProperHorizontalSpace(double value) {
    var space = screenWidth! / value;
    return space;
  }

  static Widget customSizedBox(double? width, double? height, Widget? child) {
    return SizedBox(
      width: width != null ? getProperHorizontalSpace(width) : 0,
      height: height != null ? getProperVerticalSpace(height) : 0,
      child: child,
    );
  }
}
