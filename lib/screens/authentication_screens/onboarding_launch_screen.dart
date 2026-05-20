import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/constants/colors.dart';
import '../../providers/school_provider.dart';
import '../questions_screen/questions_screen.dart';

class OnboardingLaunchScreen extends StatefulWidget {
  static const String routeName = '/launch';

  const OnboardingLaunchScreen({super.key});

  @override
  State<OnboardingLaunchScreen> createState() =>
      _OnboardingLaunchScreenState();
}

class _OnboardingLaunchScreenState extends State<OnboardingLaunchScreen> {
  static const String _guestFallbackError =
      'تعذر فتح الأسئلة السريعة الآن. حاول مرة أخرى.';

  bool _logoCentered = false;
  bool _contentVisible = false;
  bool _isStartingGuest = false;
  String? _errorMessage;
  Timer? _phaseOneTimer;
  Timer? _phaseTwoTimer;

  @override
  void initState() {
    super.initState();
    _phaseOneTimer = Timer(const Duration(milliseconds: 110), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _logoCentered = true;
      });
    });
    _phaseTwoTimer = Timer(const Duration(milliseconds: 1780), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _contentVisible = true;
      });
    });
  }

  @override
  void dispose() {
    _phaseOneTimer?.cancel();
    _phaseTwoTimer?.cancel();
    super.dispose();
  }

  Future<void> _startGuestJourney() async {
    if (_isStartingGuest) {
      return;
    }

    final schoolProvider = context.read<SchoolProvider>();

    setState(() {
      _isStartingGuest = true;
      _errorMessage = null;
    });

    try {
      await schoolProvider.getQuickQuestionsSchool();

      if (!mounted) {
        return;
      }

      Get.to(const QuestionsScreen());
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _errorMessage = message.isEmpty ? _guestFallbackError : message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStartingGuest = false;
        });
      }
    }
  }

  void _openLogin() {
    if (_isStartingGuest) {
      return;
    }

    Get.toNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final pageOneLogoSize = math.min(size.width * 0.33, 172.0);
    final pageTwoLogoSize = math.min(size.width * 0.20, 108.0);
    final logoSize = _contentVisible ? pageTwoLogoSize : pageOneLogoSize;
    final centeredLogoTop = (size.height - logoSize) * 0.47;
    final topLogoTop = padding.top + math.max(size.height * 0.04, 34.0);
    final logoTop = !_logoCentered
        ? size.height + 96
        : _contentVisible
            ? topLogoTop
            : centeredLogoTop;
    final contentHeight = math.min(
      math.max(size.height * 0.52, 412.0),
      size.height - (padding.top + 92),
    );
    final contentBottom = _contentVisible ? 0.0 : -(contentHeight + 64);

    return Scaffold(
      backgroundColor: AppColors.buttonColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              Assets.onboardingBackgroundSvg,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(26),
                    Colors.black.withAlpha(46),
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: Duration(
              milliseconds: _contentVisible ? 820 : 1480,
            ),
            curve: _contentVisible
                ? Curves.easeInOutCubic
                : Curves.easeOutCubic,
            top: logoTop,
            left: (size.width - logoSize) / 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 820),
              curve: Curves.easeInOutCubic,
              width: logoSize,
              height: logoSize,
              child: SvgPicture.asset(
                Assets.logoLightSvg,
                fit: BoxFit.contain,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 980),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: contentBottom,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 620),
              curve: Curves.easeOut,
              opacity: _contentVisible ? 1 : 0,
              child: _OnboardingContentSheet(
                height: contentHeight,
                errorMessage: _errorMessage,
                isStartingGuest: _isStartingGuest,
                onGuestPressed: _startGuestJourney,
                onLoginPressed: _openLogin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingContentSheet extends StatelessWidget {
  const _OnboardingContentSheet({
    required this.height,
    required this.errorMessage,
    required this.isStartingGuest,
    required this.onGuestPressed,
    required this.onLoginPressed,
  });

  final double height;
  final String? errorMessage;
  final bool isStartingGuest;
  final VoidCallback onGuestPressed;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final cardLogoSize = math.min(size.width * 0.22, 122.0);
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          height: 1.24,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.black.withAlpha(220),
          height: 1.62,
        );

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.panelColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
          boxShadow: [
            BoxShadow(
              color: Color(0x3306140E),
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.08,
                  child: SvgPicture.asset(
                    Assets.onboardingBackgroundSvg,
                    fit: BoxFit.cover,
                    colorFilter: const ColorFilter.mode(
                      AppColors.lineColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(28, 34, 28, 24 + bottomInset),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 330),
                          child: Text(
                            'هل تعرف كم تحفظ من القرآن الكريم اليوم؟',
                            textAlign: TextAlign.center,
                            style: titleStyle,
                          ),
                        ),
                        const SizedBox(height: 30),
                        SvgPicture.asset(
                          Assets.logoSvg,
                          width: cardLogoSize,
                          height: cardLogoSize,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 28),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 336),
                          child: Text(
                            'إن كنت ترغب في حفظ سور أو أجزاء من القرآن الكريم، أو حتى تثبيت حفظك للسور التي تحفظها، فهذا التطبيق لك.',
                            textAlign: TextAlign.center,
                            style: bodyStyle,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (errorMessage != null && errorMessage!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.errorColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        FilledButton(
                          onPressed: isStartingGuest ? null : onGuestPressed,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF666557),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isStartingGuest
                                ? const SizedBox(
                                    key: ValueKey('guest-loading'),
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'ابدأ مسيرتك الآن',
                                    key: const ValueKey('guest-label'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: isStartingGuest ? null : onLoginPressed,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(52),
                            textStyle: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          child: const Text('لدي حساب مسبقًا'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}