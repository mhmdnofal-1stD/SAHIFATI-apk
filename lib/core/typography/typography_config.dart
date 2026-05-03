import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/fonts.dart';

/// Roles that classify every piece of text in the user app by *purpose*
/// rather than by size. The set is shared between the local defaults, the
/// API payload, and the admin editor.
///
/// When you add a new role here you also need to:
///   1. Add a sensible default in [TypographyConfig.defaults].
///   2. Add a matching seed entry in the backend (frontend-users-typography
///      seed JSON) and in the admin preview catalog.
enum TypographyRole {
  // ---- Quran-specific (still admin-tunable, but uses the verses font ----).
  quranVerse,
  quranAyahMarker,
  basmala,
  surahHeading,

  // ---- Headings ----
  pageHeading,
  sectionTitle,
  subsectionTitle,
  appBarTitle,

  // ---- Body content ----
  bodyDefault,
  bodySecondary,
  bodySmall,
  emptyStateBody,

  // ---- Forms ----
  inputLabel,
  inputHint,
  inputError,

  // ---- Buttons & actions ----
  buttonPrimary,
  buttonSecondary,
  chipLabel,

  // ---- Badges & counters ----
  badgeLabel,
  badgeCount,

  // ---- Banners (info / warning / error / success) ----
  bannerTitle,
  bannerBody,

  // ---- Lists & navigation ----
  listTileTitle,
  listTileSubtitle,
  drawerItem,
  tabLabel,

  // ---- Charts ----
  chartAxisLabel,
  chartAxisTick,
  chartTooltip,

  // ---- Misc ----
  snackbarMessage,
  progressIndicatorLabel,
  userDisplayName,
  dialogTitle,
  dialogBody,
}

/// Whitelist of font families the admin is allowed to choose from.
///
/// Keys are the values stored in the API; the values are the actual Flutter
/// font family identifiers. Keep this list strictly short and curated.
class TypographyFontFamilies {
  TypographyFontFamilies._();

  static const String defaultUi = 'default-ui';
  static const String quranUthmanicScriptHafs = 'quran-uthmanic-script-hafs';
  static const String dinNextArabic = 'din-next-arabic';

  /// Resolves an admin-supplied font family key to the Flutter font family
  /// (or `null` when the platform default should be used).
  static String? resolveFamily(String? key) {
    switch (key) {
      case quranUthmanicScriptHafs:
        return AppFonts.versesFont;
      case dinNextArabic:
        return 'DIN NEXT ARABIC';
      case null:
      case defaultUi:
        return null; // Falls back to platform default (Roboto on Android).
      default:
        return null;
    }
  }

  static const List<String> whitelist = <String>[
    defaultUi,
    quranUthmanicScriptHafs,
    dinNextArabic,
  ];
}

/// Symbolic palette keys that text styles can refer to instead of hex values.
///
/// The admin editor exposes these as the canonical color choices; an optional
/// hex override (`colorHex`) may shadow the resolved palette color.
class TypographyColorTokens {
  TypographyColorTokens._();

  static const String primaryText = 'primaryText';
  static const String secondaryText = 'secondaryText';
  static const String hintText = 'hintText';
  static const String onPrimary = 'onPrimary';
  static const String error = 'error';
  static const String success = 'success';
  static const String warningTitle = 'warningTitle';
  static const String warningBody = 'warningBody';
  static const String accent = 'accent';
  static const String mutedText = 'mutedText';

  static const Map<String, Color> palette = <String, Color>{
    primaryText: AppColors.blackFontColor,
    secondaryText: AppColors.hintTextColor,
    hintText: AppColors.hintTextColor,
    onPrimary: Color(0xFFFFFFFF),
    error: AppColors.errorColor,
    success: AppColors.successColor,
    warningTitle: Color(0xFF5D3A00),
    warningBody: Color(0xFF6B4C16),
    accent: AppColors.buttonColor,
    mutedText: AppColors.mutedText,
  };

  static Color resolve(String? key,
      {Color fallback = AppColors.blackFontColor}) {
    if (key == null || key.isEmpty) return fallback;
    return palette[key] ?? fallback;
  }
}

/// Model of one role's text styling. All fields are optional in JSON; missing
/// values fall back to the local default.
@immutable
class TypographyRoleStyle {
  const TypographyRoleStyle({
    required this.fontSize,
    required this.fontWeight,
    this.height,
    this.letterSpacing,
    this.fontFamilyKey,
    this.colorKey,
    this.colorHex,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final double? height;
  final double? letterSpacing;

  /// Family key from [TypographyFontFamilies]; `null` => platform default.
  final String? fontFamilyKey;

  /// Symbolic color token (see [TypographyColorTokens]).
  final String? colorKey;

  /// Optional explicit hex override (e.g. "#5D3A00"). When present this wins
  /// over [colorKey].
  final String? colorHex;

  TypographyRoleStyle copyWith({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    String? fontFamilyKey,
    String? colorKey,
    String? colorHex,
  }) {
    return TypographyRoleStyle(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      height: height ?? this.height,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      fontFamilyKey: fontFamilyKey ?? this.fontFamilyKey,
      colorKey: colorKey ?? this.colorKey,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  TextStyle toTextStyle({Color? overrideColor}) {
    final Color resolvedColor = overrideColor ??
        _parseHex(colorHex) ??
        TypographyColorTokens.resolve(colorKey);
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: resolvedColor,
      fontFamily: TypographyFontFamilies.resolveFamily(fontFamilyKey),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fontSize': fontSize,
        'fontWeight': fontWeight.value,
        if (height != null) 'height': height,
        if (letterSpacing != null) 'letterSpacing': letterSpacing,
        if (fontFamilyKey != null) 'fontFamilyKey': fontFamilyKey,
        if (colorKey != null) 'colorKey': colorKey,
        if (colorHex != null) 'colorHex': colorHex,
      };

  static TypographyRoleStyle fromJson(
    Map<String, dynamic> json, {
    required TypographyRoleStyle fallback,
  }) {
    return TypographyRoleStyle(
      fontSize: _readDouble(json['fontSize']) ?? fallback.fontSize,
      fontWeight: _readWeight(json['fontWeight']) ?? fallback.fontWeight,
      height: _readDouble(json['height']) ?? fallback.height,
      letterSpacing:
          _readDouble(json['letterSpacing']) ?? fallback.letterSpacing,
      fontFamilyKey:
          (json['fontFamilyKey'] as String?) ?? fallback.fontFamilyKey,
      colorKey: (json['colorKey'] as String?) ?? fallback.colorKey,
      colorHex: (json['colorHex'] as String?) ?? fallback.colorHex,
    );
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static FontWeight? _readWeight(dynamic value) {
    if (value is num) {
      final int w = value.toInt();
      // Clamp to valid Material font weight values (100..900).
      const List<int> allowed = [100, 200, 300, 400, 500, 600, 700, 800, 900];
      final int snapped = allowed.reduce(
        (a, b) => (a - w).abs() < (b - w).abs() ? a : b,
      );
      switch (snapped) {
        case 100:
          return FontWeight.w100;
        case 200:
          return FontWeight.w200;
        case 300:
          return FontWeight.w300;
        case 400:
          return FontWeight.w400;
        case 500:
          return FontWeight.w500;
        case 600:
          return FontWeight.w600;
        case 700:
          return FontWeight.w700;
        case 800:
          return FontWeight.w800;
        case 900:
          return FontWeight.w900;
      }
    }
    return null;
  }

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    String cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    if (cleaned.length != 8) return null;
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(value);
  }
}

/// Full typography configuration: a map of role → style plus version metadata.
@immutable
class TypographyConfig {
  const TypographyConfig({
    required this.styles,
    this.version,
    this.updatedAt,
  });

  final Map<TypographyRole, TypographyRoleStyle> styles;
  final int? version;
  final String? updatedAt;

  TypographyRoleStyle styleFor(TypographyRole role) {
    return styles[role] ?? defaults.styles[role]!;
  }

  TypographyConfig mergeWith(TypographyConfig override) {
    final next = Map<TypographyRole, TypographyRoleStyle>.from(styles);
    for (final entry in override.styles.entries) {
      next[entry.key] = entry.value;
    }
    return TypographyConfig(
      styles: next,
      version: override.version ?? version,
      updatedAt: override.updatedAt ?? updatedAt,
    );
  }

  /// Local hard-coded defaults — used when the API has not yet been reached
  /// and as the merge baseline so any missing role still resolves to a style.
  static const TypographyConfig defaults = TypographyConfig(
    styles: <TypographyRole, TypographyRoleStyle>{
      TypographyRole.quranVerse: TypographyRoleStyle(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        height: 1.8,
        fontFamilyKey: TypographyFontFamilies.quranUthmanicScriptHafs,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.quranAyahMarker: TypographyRoleStyle(
        fontSize: 19.2,
        fontWeight: FontWeight.w700,
        fontFamilyKey: TypographyFontFamilies.quranUthmanicScriptHafs,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.basmala: TypographyRoleStyle(
        fontSize: 19.28,
        fontWeight: FontWeight.w600,
        height: 1.08,
        fontFamilyKey: TypographyFontFamilies.quranUthmanicScriptHafs,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.surahHeading: TypographyRoleStyle(
        fontSize: 19.28,
        fontWeight: FontWeight.w700,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.pageHeading: TypographyRoleStyle(
        fontSize: 19.28,
        fontWeight: FontWeight.w800,
        height: 1.035,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.sectionTitle: TypographyRoleStyle(
        fontSize: 19.22,
        fontWeight: FontWeight.w800,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.subsectionTitle: TypographyRoleStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.appBarTitle: TypographyRoleStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.bodyDefault: TypographyRoleStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.05,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.bodySecondary: TypographyRoleStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.045,
        colorKey: TypographyColorTokens.secondaryText,
      ),
      TypographyRole.bodySmall: TypographyRoleStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.emptyStateBody: TypographyRoleStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.05,
        colorKey: TypographyColorTokens.secondaryText,
      ),
      TypographyRole.inputLabel: TypographyRoleStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        colorKey: TypographyColorTokens.mutedText,
      ),
      TypographyRole.inputHint: TypographyRoleStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        colorKey: TypographyColorTokens.mutedText,
      ),
      TypographyRole.inputError: TypographyRoleStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        colorKey: TypographyColorTokens.error,
      ),
      TypographyRole.buttonPrimary: TypographyRoleStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        colorKey: TypographyColorTokens.onPrimary,
      ),
      TypographyRole.buttonSecondary: TypographyRoleStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        colorKey: TypographyColorTokens.accent,
      ),
      TypographyRole.chipLabel: TypographyRoleStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.badgeLabel: TypographyRoleStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        colorKey: TypographyColorTokens.accent,
      ),
      TypographyRole.badgeCount: TypographyRoleStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        colorKey: TypographyColorTokens.warningTitle,
      ),
      TypographyRole.bannerTitle: TypographyRoleStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        colorKey: TypographyColorTokens.warningTitle,
      ),
      TypographyRole.bannerBody: TypographyRoleStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        colorKey: TypographyColorTokens.warningBody,
      ),
      TypographyRole.listTileTitle: TypographyRoleStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.listTileSubtitle: TypographyRoleStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        colorKey: TypographyColorTokens.secondaryText,
      ),
      TypographyRole.drawerItem: TypographyRoleStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.tabLabel: TypographyRoleStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.chartAxisLabel: TypographyRoleStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.chartAxisTick: TypographyRoleStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        colorKey: TypographyColorTokens.secondaryText,
      ),
      TypographyRole.chartTooltip: TypographyRoleStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        colorKey: TypographyColorTokens.secondaryText,
      ),
      TypographyRole.snackbarMessage: TypographyRoleStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        colorKey: TypographyColorTokens.onPrimary,
      ),
      TypographyRole.progressIndicatorLabel: TypographyRoleStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.userDisplayName: TypographyRoleStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.dialogTitle: TypographyRoleStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        colorKey: TypographyColorTokens.primaryText,
      ),
      TypographyRole.dialogBody: TypographyRoleStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        colorKey: TypographyColorTokens.primaryText,
      ),
    },
    version: 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        if (updatedAt != null) 'updatedAt': updatedAt,
        'styles': <String, dynamic>{
          for (final entry in styles.entries)
            entry.key.name: entry.value.toJson(),
        },
      };

  /// Parses a server payload of shape `{ version, updatedAt, styles: { roleName: {...} } }`.
  /// Unknown roles are ignored; missing roles fall back to defaults.
  static TypographyConfig fromJson(Map<String, dynamic> json) {
    final raw = json['styles'];
    final Map<TypographyRole, TypographyRoleStyle> next =
        <TypographyRole, TypographyRoleStyle>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final role = _roleByName(entry.key.toString());
        if (role == null) continue;
        final value = entry.value;
        if (value is! Map) continue;
        next[role] = TypographyRoleStyle.fromJson(
          value.map((k, v) => MapEntry(k.toString(), v)),
          fallback: defaults.styleFor(role),
        );
      }
    }

    final merged = <TypographyRole, TypographyRoleStyle>{
      ...defaults.styles,
      ...next,
    };

    return TypographyConfig(
      styles: merged,
      version:
          (json['version'] is num) ? (json['version'] as num).toInt() : null,
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  static TypographyRole? _roleByName(String name) {
    for (final role in TypographyRole.values) {
      if (role.name == name) return role;
    }
    return null;
  }
}
