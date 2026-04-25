import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/constants/assets.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/constants/fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final hasSubtitle = subtitle.trim().isNotEmpty;
    final isCompactPhone =
        preferCompactMobileLayout && mediaQuery.size.shortestSide < 600;
    final outerHorizontalPadding = isCompactPhone ? 16.0 : 20.0;
    final outerTopPadding = isCompactPhone ? 12.0 : 20.0;
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
      backgroundColor: const Color(0xFFF5F0E8),
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
                  final minViewportHeight = fillViewport &&
                          viewportConstraints.maxHeight.isFinite
                      ? viewportConstraints.maxHeight -
                          outerTopPadding -
                          outerBottomPadding
                      : 0.0;
                  final normalizedMinViewportHeight = minViewportHeight > 0
                      ? minViewportHeight
                      : 0.0;

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
                              color: const Color(0xFFFCFBF8),
                              borderRadius: BorderRadius.circular(cardRadius),
                              border: Border.all(
                                color: const Color(0xFFE9E0D2),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x140F172A),
                                  blurRadius: 40,
                                  offset: Offset(0, 20),
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
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppFonts.primaryFont,
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF132A4A),
                                      height: 1.15,
                                    ),
                                  ),
                                  if (hasSubtitle) ...[
                                    SizedBox(height: titleSpacing),
                                    Text(
                                      subtitle,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: AppFonts.primaryFont,
                                        fontSize: 14,
                                        color: const Color(0xFF6C7280),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: contentSpacing),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 20,
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
            style: TextStyle(
              fontFamily: AppFonts.primaryFont,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: const Color(0xFF132A4A),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primaryPurple,
            size: 18,
          ),
        ),
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
        color: const Color(0xFFF1ECE3),
        borderRadius: BorderRadius.circular(20),
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
      color: isSelected ? Colors.white : Colors.transparent,
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
                color: isSelected
                    ? const Color(0xFF132A4A)
                    : const Color(0xFF7A808A),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? const Color(0xFF132A4A)
                        : const Color(0xFF7A808A),
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
                colors: [Color(0x669FC4FF), Color(0x009FC4FF)],
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
                colors: [Color(0x66EBC48E), Color(0x00EBC48E)],
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
                colors: [Color(0x22C3D6F5), Color(0x22F6E7CD)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}