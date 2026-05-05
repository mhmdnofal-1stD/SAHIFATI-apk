import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/providers/language_provider.dart';

class AuthLanguageSwitch extends StatelessWidget {
  const AuthLanguageSwitch({
    super.key,
    this.backgroundColor = const Color(0xFFFFFCF8),
    this.borderColor = const Color(0xFFD7D8DE),
    this.foregroundColor = const Color(0xFF132A4A),
    this.shadowColor = const Color(0x0813284A),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;

  String _targetLanguageCode(String currentCode) {
    return currentCode.toLowerCase() == 'en' ? 'ar' : 'en';
  }

  String _targetLanguageLabel(String languageCode) {
    return languageCode == 'ar' ? 'العربية' : 'English';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final targetCode = _targetLanguageCode(languageProvider.langCode);
        final targetLabel = _targetLanguageLabel(targetCode);

        return Tooltip(
          message: 'language'.tr,
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await languageProvider.changeLanguage(targetCode);
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
                        targetLabel,
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
      backgroundColor: const Color(0xFFF2E9DD),
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
                              color: const Color(0xFFFFFCF7),
                              borderRadius: BorderRadius.circular(cardRadius),
                              border: Border.all(
                                color: const Color(0xFFE0D3C0),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1813284A),
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
                                  const _BrandHeader(),
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
                                            color: const Color(0xFF132A4A),
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
                                              color: const Color(0xFF556277),
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
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5D9C8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1413284A),
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
          child: Text(
            'SAHIFATI',
            style: AppTypography.of(context).badgeLabel.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: const Color(0xFF173054),
                ),
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
        color: const Color(0xFFF0E7DB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0D2BF)),
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
      color: isSelected ? const Color(0xFF132A4A) : Colors.transparent,
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
                color: isSelected ? Colors.white : const Color(0xFF5E6A7E),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.of(context).buttonSecondary.copyWith(
                        fontSize: 13,
                        color:
                            isSelected ? Colors.white : const Color(0xFF5E6A7E),
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
                colors: [Color(0x80B5CCFF), Color(0x00B5CCFF)],
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
                colors: [Color(0x7AE2C48D), Color(0x00E2C48D)],
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
                colors: [Color(0x30C5D8F3), Color(0x34F5DFC1)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
