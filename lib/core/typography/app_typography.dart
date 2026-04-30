import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'typography_config.dart';

/// Holds the active [TypographyConfig] and notifies listeners when the admin
/// pushes a new revision.
class TypographyConfigController extends ChangeNotifier {
  TypographyConfigController([TypographyConfig? initial])
      : _config = initial ?? TypographyConfig.defaults;

  TypographyConfig _config;
  TypographyConfig get config => _config;

  void update(TypographyConfig next) {
    _config = TypographyConfig.defaults.mergeWith(next);
    notifyListeners();
  }

  /// Replaces the config without going through the merge step. Intended for
  /// admin previews where the caller already produced a complete map.
  void replace(TypographyConfig next) {
    _config = next;
    notifyListeners();
  }

  void resetToDefaults() {
    _config = TypographyConfig.defaults;
    notifyListeners();
  }
}

/// Purpose-driven typography facade. **Always read styles through this class**
/// instead of constructing [TextStyle] inline. The admin can re-skin the app
/// by editing one of the underlying roles.
///
/// Usage:
/// ```dart
/// Text('مرحبا', style: AppTypography.of(context).pageHeading)
/// ```
///
/// Or, when no [BuildContext] is available, use the static fallback:
/// ```dart
/// Text('مرحبا', style: AppTypography.fallback.pageHeading)
/// ```
class AppTypography {
  AppTypography._(this._config);

  final TypographyConfig _config;

  static AppTypography fallback = AppTypography._(TypographyConfig.defaults);

  factory AppTypography.of(BuildContext context, {bool listen = true}) {
    final controller = listen
        ? context.watch<TypographyConfigController?>()
        : context.read<TypographyConfigController?>();
    return AppTypography._(controller?.config ?? TypographyConfig.defaults);
  }

  TextStyle styleOf(TypographyRole role, {Color? color}) {
    return _config.styleFor(role).toTextStyle(overrideColor: color);
  }

  // ---- Convenience getters (one per role) ----------------------------------
  TextStyle get quranVerse => styleOf(TypographyRole.quranVerse);
  TextStyle get quranAyahMarker => styleOf(TypographyRole.quranAyahMarker);
  TextStyle get basmala => styleOf(TypographyRole.basmala);
  TextStyle get surahHeading => styleOf(TypographyRole.surahHeading);

  TextStyle get pageHeading => styleOf(TypographyRole.pageHeading);
  TextStyle get sectionTitle => styleOf(TypographyRole.sectionTitle);
  TextStyle get subsectionTitle => styleOf(TypographyRole.subsectionTitle);
  TextStyle get appBarTitle => styleOf(TypographyRole.appBarTitle);

  TextStyle get bodyDefault => styleOf(TypographyRole.bodyDefault);
  TextStyle get bodySecondary => styleOf(TypographyRole.bodySecondary);
  TextStyle get bodySmall => styleOf(TypographyRole.bodySmall);
  TextStyle get emptyStateBody => styleOf(TypographyRole.emptyStateBody);

  TextStyle get inputLabel => styleOf(TypographyRole.inputLabel);
  TextStyle get inputHint => styleOf(TypographyRole.inputHint);
  TextStyle get inputError => styleOf(TypographyRole.inputError);

  TextStyle get buttonPrimary => styleOf(TypographyRole.buttonPrimary);
  TextStyle get buttonSecondary => styleOf(TypographyRole.buttonSecondary);
  TextStyle get chipLabel => styleOf(TypographyRole.chipLabel);

  TextStyle get badgeLabel => styleOf(TypographyRole.badgeLabel);
  TextStyle get badgeCount => styleOf(TypographyRole.badgeCount);

  TextStyle get bannerTitle => styleOf(TypographyRole.bannerTitle);
  TextStyle get bannerBody => styleOf(TypographyRole.bannerBody);

  TextStyle get listTileTitle => styleOf(TypographyRole.listTileTitle);
  TextStyle get listTileSubtitle => styleOf(TypographyRole.listTileSubtitle);
  TextStyle get drawerItem => styleOf(TypographyRole.drawerItem);
  TextStyle get tabLabel => styleOf(TypographyRole.tabLabel);

  TextStyle get chartAxisLabel => styleOf(TypographyRole.chartAxisLabel);
  TextStyle get chartAxisTick => styleOf(TypographyRole.chartAxisTick);
  TextStyle get chartTooltip => styleOf(TypographyRole.chartTooltip);

  TextStyle get snackbarMessage => styleOf(TypographyRole.snackbarMessage);
  TextStyle get progressIndicatorLabel =>
      styleOf(TypographyRole.progressIndicatorLabel);
  TextStyle get userDisplayName => styleOf(TypographyRole.userDisplayName);
  TextStyle get dialogTitle => styleOf(TypographyRole.dialogTitle);
  TextStyle get dialogBody => styleOf(TypographyRole.dialogBody);
}

/// Convenience extension so call sites can write
/// `context.appText.bodyDefault` instead of `AppTypography.of(context).bodyDefault`.
extension TypographyContextExt on BuildContext {
  AppTypography get appText => AppTypography.of(this);
}
