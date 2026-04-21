import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildGoogleWebButton({
  required bool isSignupContext,
  required String? locale,
}) {
  return google_web.renderButton(
    configuration: google_web.GSIButtonConfiguration(
      type: google_web.GSIButtonType.icon,
      theme: google_web.GSIButtonTheme.outline,
      size: google_web.GSIButtonSize.large,
      shape: google_web.GSIButtonShape.pill,
      locale: locale,
    ),
  );
}