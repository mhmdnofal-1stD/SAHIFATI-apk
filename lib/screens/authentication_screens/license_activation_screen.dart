import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/auth/post_auth_navigation.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/constants/fonts.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  State<LicenseActivationScreen> createState() =>
      _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  late final Future<void> _bootstrapFuture;
  final TextEditingController _promoCodeController = TextEditingController();
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();

    if (usersProvider.selectedUser == null) {
      final isLoggedIn = await usersProvider.tryAutoLogin();
      if (!isLoggedIn || usersProvider.selectedUser == null) {
        if (mounted) {
          Get.offAllNamed('/');
        }
        return;
      }
    }

    await usersProvider.ensureLicenseStateLoaded(forceRefresh: true);
    if (usersProvider.hasActiveLicense && mounted) {
      await _continueWithActiveLicense(usersProvider, evaluationsProvider);
    }
  }

  Future<void> _continueWithActiveLicense(
    UsersProvider usersProvider,
    EvaluationsProvider evaluationsProvider,
  ) async {
    await navigateAfterSuccessfulLogin(
      userId: usersProvider.selectedUser!.id,
      isFirstLogin: usersProvider.isFirstLogin,
      hasActiveLicense: usersProvider.hasActiveLicense,
      loadChartData: (userId) => evaluationsProvider.getQuranChartData(userId),
    );
  }

  Future<void> _activateFromGift() async {
    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();

    setState(() {
      _inlineError = null;
    });

    try {
      await usersProvider.activateGiftLicense();
      if (!mounted || usersProvider.selectedUser == null) {
        return;
      }

      await _continueWithActiveLicense(usersProvider, evaluationsProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inlineError = usersProvider.extractErrorMessage(error);
      });
    }
  }

  Future<void> _activateFromPromo() async {
    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final promoCode = _promoCodeController.text.trim();

    if (promoCode.isEmpty) {
      setState(() {
        _inlineError = 'license_activation_promo_missing_code'.tr;
      });
      return;
    }

    setState(() {
      _inlineError = null;
    });

    try {
      await usersProvider.activatePromoLicense(promoCode);
      if (!mounted || usersProvider.selectedUser == null) {
        return;
      }

      await _continueWithActiveLicense(usersProvider, evaluationsProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inlineError = usersProvider.extractErrorMessage(error);
      });
    }
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String body,
    required Color accent,
    VoidCallback? onTap,
    bool enabled = true,
    String? footer,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackFontColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppFonts.primaryFont,
              fontSize: 13,
              height: 1.6,
              color: AppColors.hintTextColor,
            ),
          ),
          if (child != null) ...[
            const SizedBox(height: 14),
            child,
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: enabled ? onTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                disabledBackgroundColor: const Color(0xFFE8EBF1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                footer ??
                    (enabled
                        ? 'license_activation_continue'.tr
                        : 'license_activation_coming_soon'.tr),
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppFonts.primaryFont,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : const Color(0xFF7E8795),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<UsersProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: FutureBuilder<void>(
        future: _bootstrapFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              usersProvider.selectedUser == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF183C63), Color(0xFF2A638B)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'license_activation_title'.tr,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: AppFonts.primaryFont,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'license_activation_body'.tr,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: AppFonts.primaryFont,
                                fontSize: 14,
                                height: 1.7,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                'license_activation_status_pending'.tr,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: AppFonts.primaryFont,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_inlineError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.errorColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color:
                                  AppColors.errorColor.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            _inlineError!,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: AppFonts.primaryFont,
                              color: AppColors.errorColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildOptionCard(
                        icon: Icons.volunteer_activism_rounded,
                        title: 'license_activation_gift_title'.tr,
                        body: 'license_activation_gift_body'.tr,
                        accent: const Color(0xFF0F7A67),
                        enabled: !usersProvider.isLicenseLoading,
                        onTap: _activateFromGift,
                        footer: usersProvider.isLicenseLoading
                            ? 'license_activation_gift_loading'.tr
                            : 'license_activation_gift_action'.tr,
                      ),
                      const SizedBox(height: 14),
                      _buildOptionCard(
                        icon: Icons.local_offer_outlined,
                        title: 'license_activation_promo_title'.tr,
                        body: 'license_activation_promo_body'.tr,
                        accent: const Color(0xFF8A5A12),
                        enabled: !usersProvider.isLicenseLoading,
                        onTap: _activateFromPromo,
                        footer: usersProvider.isLicenseLoading
                            ? 'license_activation_promo_loading'.tr
                            : 'license_activation_promo_action'.tr,
                        child: TextField(
                          controller: _promoCodeController,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.characters,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: AppFonts.primaryFont,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blackFontColor,
                          ),
                          decoration: InputDecoration(
                            hintText: 'license_activation_promo_hint'.tr,
                            hintStyle: TextStyle(
                              fontFamily: AppFonts.primaryFont,
                              color: AppColors.hintTextColor,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8F4EA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildOptionCard(
                        icon: Icons.shopping_cart_checkout_outlined,
                        title: 'license_activation_purchase_title'.tr,
                        body: 'license_activation_purchase_body'.tr,
                        accent: const Color(0xFF5B3DA1),
                        enabled: false,
                        footer: 'license_activation_coming_soon'.tr,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'license_activation_purchase_deferred_notice'.tr,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: AppFonts.primaryFont,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5B3DA1),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'license_activation_bundle_20'.tr,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: AppFonts.primaryFont,
                                color: AppColors.hintTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'license_activation_bundle_100'.tr,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: AppFonts.primaryFont,
                                color: AppColors.hintTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'license_activation_bundle_1000'.tr,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: AppFonts.primaryFont,
                                color: AppColors.hintTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'license_activation_bundle_10000'.tr,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: AppFonts.primaryFont,
                                color: AppColors.hintTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: () async {
                          await usersProvider.logout();
                          if (!mounted) {
                            return;
                          }
                          Get.offAllNamed('/login');
                        },
                        child: Text(
                          'license_activation_logout'.tr,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: AppFonts.primaryFont,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
