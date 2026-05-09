import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/providers/language_provider.dart';

class AuthLanguageSwitch extends StatelessWidget {
  const AuthLanguageSwitch({
    super.key,
    this.backgroundColor = AppColors.panelColor,
    this.borderColor = AppColors.lineColor,
    this.foregroundColor = AppColors.blackFontColor,
    this.shadowColor = const Color(0x141D6652),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;

  List<Map<String, String>> _availableLanguages(LanguageProvider languageProvider) {
    final languages = <Map<String, String>>[];

    for (final entry in languageProvider.languages) {
      final code = entry['code']?.toString().trim().toLowerCase() ?? '';
      final name = entry['name']?.toString().trim() ?? '';
      if (code.isEmpty || name.isEmpty) {
        continue;
      }

      languages.add({'code': code, 'name': name});
    }

    return languages;
  }

  String _currentLanguageLabel(LanguageProvider languageProvider) {
    for (final language in _availableLanguages(languageProvider)) {
      if (language['code'] == languageProvider.langCode.toLowerCase()) {
        return language['name']!;
      }
    }

    return languageProvider.langCode.toUpperCase();
  }

  Future<void> _openLanguagePicker(
    BuildContext context,
    LanguageProvider languageProvider,
  ) async {
    if (!languageProvider.isLoadingLanguages &&
        !languageProvider.hasFetchedLanguages) {
      await languageProvider.fetchLanguages();
    }

    if (!context.mounted) {
      return;
    }

    final languages = _availableLanguages(languageProvider);
    if (languages.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final typography = AppTypography.of(sheetContext);

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'language'.tr,
                  style: typography.sectionTitle,
                ),
              ),
              for (final language in languages)
                ListTile(
                  title: Text(language['name']!),
                  trailing: language['code'] ==
                          languageProvider.langCode.toLowerCase()
                      ? Icon(
                          Icons.check,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await languageProvider.changeLanguage(language['code']!);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final currentLabel = _currentLanguageLabel(languageProvider);

        return Tooltip(
          message: 'language'.tr,
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await _openLanguagePicker(context, languageProvider);
              },
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    if (shadowColor.a > 0)
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language_rounded,
                        size: 16,
                        color: foregroundColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentLabel,
                        style: AppTypography.of(context).badgeLabel.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: foregroundColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSignup,
    required this.child,
    this.brandSubtitle,
    this.onSelectLogin,
    this.onSelectSignup,
    this.maxWidth = 440,
    this.fillViewport = false,
    this.preferCompactMobileLayout = false,
    this.showHeading = true,
  });

  final String title;
  final String subtitle;
  final bool isSignup;
  final Widget child;
  final String? brandSubtitle;
  final VoidCallback? onSelectLogin;
  final VoidCallback? onSelectSignup;
  final double maxWidth;
  final bool fillViewport;
  final bool preferCompactMobileLayout;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final hasSubtitle = subtitle.trim().isNotEmpty;
    final isCompactPhone =
        preferCompactMobileLayout && mediaQuery.size.shortestSide < 600;
    final outerHorizontalPadding = isCompactPhone ? 16.0 : 24.0;
    final outerTopPadding = isCompactPhone ? 16.0 : 28.0;
    final outerBottomPadding = bottomInset > 24
        ? bottomInset + (isCompactPhone ? 16.0 : 24.0)
        : (isCompactPhone ? 16.0 : 24.0);
    final cardRadius = isCompactPhone ? 28.0 : 32.0;
    final cardHorizontalPadding = isCompactPhone ? 18.0 : 22.0;
    final cardTopPadding = isCompactPhone ? 18.0 : 22.0;
    final cardBottomPadding = isCompactPhone ? 20.0 : 24.0;
    final headerSpacing = isCompactPhone ? 16.0 : 22.0;
    final modeSpacing = isCompactPhone ? 16.0 : 20.0;
    final titleSpacing = isCompactPhone ? 6.0 : 8.0;
    final contentSpacing = isCompactPhone ? 18.0 : 24.0;
    final titleFontSize = isCompactPhone ? 22.0 : 24.0;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _AuthBackdrop(),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(
                builder: (context, viewportConstraints) {
                  final minViewportHeight =
                      fillViewport && viewportConstraints.maxHeight.isFinite
                          ? viewportConstraints.maxHeight -
                              outerTopPadding -
                              outerBottomPadding
                          : 0.0;
                  final normalizedMinViewportHeight =
                      minViewportHeight > 0 ? minViewportHeight : 0.0;

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      outerHorizontalPadding,
                      outerTopPadding,
                      outerHorizontalPadding,
                      outerBottomPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: normalizedMinViewportHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.panelColor,
                              borderRadius: BorderRadius.circular(cardRadius),
                              border: Border.all(
                                color: AppColors.lineColor,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x141D6652),
                                  blurRadius: 48,
                                  offset: Offset(0, 24),
                                ),
                                BoxShadow(
                                  color: Color(0x08FFFFFF),
                                  blurRadius: 18,
                                  offset: Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                cardHorizontalPadding,
                                cardTopPadding,
                                cardHorizontalPadding,
                                cardBottomPadding,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _BrandHeader(brandSubtitle: brandSubtitle),
                                  SizedBox(height: headerSpacing),
                                  _AuthModeToggle(
                                    isSignup: isSignup,
                                    onSelectLogin: onSelectLogin,
                                    onSelectSignup: onSelectSignup,
                                  ),
                                  SizedBox(height: modeSpacing),
                                  if (showHeading) ...[
                                    Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.of(context)
                                          .pageHeading
                                          .copyWith(
                                            fontSize: titleFontSize,
                                            color: AppColors.blackFontColor,
                                            height: 1.15,
                                          ),
                                    ),
                                    if (hasSubtitle) ...[
                                      SizedBox(height: titleSpacing),
                                      Text(
                                        subtitle,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.of(context)
                                            .bodySecondary
                                            .copyWith(
                                              color: AppColors.mutedText,
                                              height: 1.5,
                                            ),
                                      ),
                                    ],
                                    SizedBox(height: contentSpacing),
                                  ],
                                  child,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.brandSubtitle});

  final String? brandSubtitle;

  @override
  Widget build(BuildContext context) {
    final hasBrandSubtitle = brandSubtitle?.trim().isNotEmpty ?? false;

    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.mintSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.lineColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x141D6652),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SvgPicture.asset(Assets.logoSvg),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'صحيفتي',
                style: AppTypography.of(context).pageHeading.copyWith(
                      fontSize: 28,
                      color: AppColors.blackFontColor,
                      height: 1.0,
                    ),
              ),
              if (hasBrandSubtitle) ...[
                const SizedBox(height: 4),
                Text(
                  brandSubtitle!,
                  style: AppTypography.of(context).bodySmall.copyWith(
                        color: AppColors.mutedText,
                        height: 1.4,
                      ),
                ),
              ],
            ],
          ),
        ),
        const AuthLanguageSwitch(),
      ],
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({
    required this.isSignup,
    this.onSelectLogin,
    this.onSelectSignup,
  });

  final bool isSignup;
  final VoidCallback? onSelectLogin;
  final VoidCallback? onSelectSignup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.mintSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeItem(
              label: 'auth_mode_login'.tr,
              icon: Icons.login_rounded,
              isSelected: !isSignup,
              onTap: onSelectLogin,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeItem(
              label: 'auth_mode_signup'.tr,
              icon: Icons.person_add_alt_1_rounded,
              isSelected: isSignup,
              onTap: onSelectSignup,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primaryPurple : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? Colors.white : AppColors.mutedText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.of(context).buttonSecondary.copyWith(
                        fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.mutedText,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x52EDF3D7), Color(0x00EDF3D7)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: -50,
          child: Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x332F7B64), Color(0x002F7B64)],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: 20,
          right: 20,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(90),
              gradient: const LinearGradient(
                colors: [Color(0x16EDF3D7), Color(0x121D6652)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
