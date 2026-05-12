import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

// Not used on web; the GIS button from buildGoogleWebButton handles auth
// via the authenticationEvents stream set up in GoogleWebAuthButton._initialize().
Future<void> triggerGoogleAuthenticate() async {}

Widget buildGoogleWebButton({
  required bool isSignupContext,
  required String? locale,
}) {
  final plugin = GoogleSignInPlatform.instance as GoogleSignInPlugin;
  return plugin.renderButton(
    configuration: GSIButtonConfiguration(
      type: GSIButtonType.icon,
      size: GSIButtonSize.large,
      theme: GSIButtonTheme.outline,
      locale: locale,
    ),
  );
}