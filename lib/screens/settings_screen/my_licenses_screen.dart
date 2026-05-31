import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/soft_pattern_background.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sahifaty/core/auth/purchase_return_flow.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/info_icon_button.dart';

class MyLicensesScreen extends StatefulWidget {
  const MyLicensesScreen({super.key});

  @override
  State<MyLicensesScreen> createState() => _MyLicensesScreenState();
}

class _MyLicensesScreenState extends State<MyLicensesScreen>
    with WidgetsBindingObserver {
  late final Future<void> _loadFuture;
  final TextEditingController _maxUsesController =
      TextEditingController(text: '1');
  final TextEditingController _giftContributionController =
      TextEditingController(text: '1');
  String? _recentRawCode;
  int _selectedPurchaseQuantity = 20;
  String? _purchaseError;
  String? _purchaseNotice;
  Color _purchaseNoticeAccent = const Color(0xFF2A638B);
  IconData _purchaseNoticeIcon = Icons.info_outline_rounded;
  bool _awaitingPurchaseReturn = false;
  int? _purchaseOwnedBaseline;

  bool get _isArabic => Get.locale?.languageCode.toLowerCase() == 'ar';
  TextDirection get _textDirection =>
      _isArabic ? TextDirection.rtl : TextDirection.ltr;
    bool get _hidePurchaseBundlesForApple =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFuture = _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _maxUsesController.dispose();
    _giftContributionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_awaitingPurchaseReturn) {
      return;
    }

    _awaitingPurchaseReturn = false;
    unawaited(
      _refreshPurchaseWorkspace(
        showCheckingNotice: true,
        showReviewNoticeWhenUnchanged: false,
      ),
    );
  }

  Future<void> _bootstrap() async {
    final usersProvider = context.read<UsersProvider>();
    if (usersProvider.activeAccountUser == null) {
      final isLoggedIn = await usersProvider.tryAutoLogin();
      if (!isLoggedIn || usersProvider.activeAccountUser == null) {
        if (mounted) {
          Get.offAllNamed('/login');
        }
        return;
      }
    }
    await usersProvider.loadPromoWorkspace(forceRefresh: true);
    await _applyPurchaseReturnIntent();
  }

  String _formatDate(dynamic rawValue) {
    if (rawValue == null) {
      return 'license_hub_date_not_set'.tr;
    }
    final parsed = DateTime.tryParse(rawValue.toString());
    if (parsed == null) {
      return rawValue.toString();
    }
    final date = parsed.toLocal();
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: _textDirection),
          backgroundColor: isError ? Colors.red.shade700 : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showPurchaseNotice(
    String message, {
    Color accent = const Color(0xFF2A638B),
    IconData icon = Icons.info_outline_rounded,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _purchaseNotice = message;
      _purchaseNoticeAccent = accent;
      _purchaseNoticeIcon = icon;
    });
  }

  Widget _buildPurchaseNotice() {
    final foregroundColor = _purchaseNoticeAccent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _purchaseNoticeAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _purchaseNoticeAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_purchaseNoticeIcon, color: foregroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _purchaseNotice!,
              textDirection: _textDirection,
              style: AppTypography.of(context).bodyDefault.copyWith(
                    color: foregroundColor,
                    height: 1.6,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  PurchaseReturnIntent _resolvePurchaseReturnIntent() {
    return resolvePurchaseReturnRoute(
      Uri.base,
      explicitStatus: Get.parameters['purchase'],
    );
  }

  int _currentOwnedCount(UsersProvider usersProvider) {
    return ((usersProvider.licenseBalanceSummary?['ownedCount'] ?? 0) as num)
        .toInt();
  }

  Future<void> _applyPurchaseReturnIntent() async {
    final purchaseReturnIntent = _resolvePurchaseReturnIntent();
    switch (purchaseReturnIntent.kind) {
      case PurchaseReturnKind.none:
        return;
      case PurchaseReturnKind.success:
        await _refreshPurchaseWorkspace(
          showCheckingNotice: true,
          showReviewNoticeWhenUnchanged: true,
        );
        return;
      case PurchaseReturnKind.failure:
        _showPurchaseNotice(
          'license_activation_purchase_return_failed'.tr,
          accent: AppColors.errorColor,
          icon: Icons.error_outline_rounded,
        );
        return;
      case PurchaseReturnKind.cancelled:
        _showPurchaseNotice(
          'license_activation_purchase_return_cancelled'.tr,
          accent: const Color(0xFF8A5A12),
          icon: Icons.remove_circle_outline_rounded,
        );
        return;
    }
  }

  Future<void> _refreshPurchaseWorkspace({
    bool showCheckingNotice = false,
    bool showReviewNoticeWhenUnchanged = false,
  }) async {
    final usersProvider = context.read<UsersProvider>();
    final baselineOwnedCount =
        _purchaseOwnedBaseline ?? _currentOwnedCount(usersProvider);

    setState(() {
      _purchaseError = null;
    });

    if (showCheckingNotice) {
      _showPurchaseNotice(
        'license_activation_purchase_return_checking'.tr,
        accent: const Color(0xFF2A638B),
        icon: Icons.autorenew_rounded,
      );
    }

    await usersProvider.loadPromoWorkspace(forceRefresh: true);

    if (!mounted) {
      return;
    }

    final workspaceError = usersProvider.promoWorkspaceError;
    if (workspaceError != null && workspaceError.isNotEmpty) {
      setState(() {
        _purchaseError = workspaceError;
      });
      return;
    }

    final refreshedOwnedCount = _currentOwnedCount(usersProvider);
    if (refreshedOwnedCount > baselineOwnedCount) {
      _purchaseOwnedBaseline = refreshedOwnedCount;
      _showPurchaseNotice(
        'license_activation_purchase_return_balance_updated'.tr,
        accent: AppColors.successColor,
        icon: Icons.check_circle_outline_rounded,
      );
      return;
    }

    if (showReviewNoticeWhenUnchanged) {
      _showPurchaseNotice(
        'license_activation_purchase_return_review_balance'.tr,
        accent: const Color(0xFF2A638B),
        icon: Icons.account_balance_wallet_outlined,
      );
      return;
    }

    _showPurchaseNotice(
      'license_activation_purchase_pending_after_check'.tr,
      accent: const Color(0xFFB26A12),
      icon: Icons.hourglass_top_rounded,
    );
  }

  Future<void> _createPromoCode(int ownedCount) async {
    final usersProvider = context.read<UsersProvider>();
    final value = int.tryParse(_maxUsesController.text.trim()) ?? 0;
    if (value < 1) {
      _showSnack('license_hub_max_uses_invalid'.tr, isError: true);
      return;
    }
    if (value > ownedCount) {
      _showSnack(
        'license_hub_max_uses_exceeds'.trParams({
          'max': ownedCount.toString(),
        }),
        isError: true,
      );
      return;
    }

    try {
      final createdPromo = await usersProvider.createPromoCode(maxUses: value);
      if (!mounted) return;
      setState(() {
        _recentRawCode = createdPromo['rawCode'] as String?;
      });
      _showSnack(
        'license_hub_create_success'.trParams({'count': value.toString()}),
      );
    } catch (error) {
      _showSnack(usersProvider.extractErrorMessage(error), isError: true);
    }
  }

  Future<void> _contributeToGiftPool(int ownedCount) async {
    final usersProvider = context.read<UsersProvider>();
    final quantity = int.tryParse(_giftContributionController.text.trim()) ?? 0;

    if (quantity < 1) {
      _showSnack('license_hub_max_uses_invalid'.tr, isError: true);
      return;
    }
    if (quantity > ownedCount) {
      _showSnack('license_hub_gift_pool_not_enough'.tr, isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('license_hub_gift_pool_confirm_title'.tr),
        content: Text(
          'license_hub_gift_pool_confirm_body'.trParams({
            'count': quantity.toString(),
          }),
          textDirection: _textDirection,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('license_hub_gift_pool_action'.tr),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response =
          await usersProvider.contributeToGiftPool(quantity: quantity);
      if (!mounted) return;
      _showSnack(
        'license_hub_gift_pool_success'.trParams({
          'count': (response['quantityContributed'] ?? quantity).toString(),
        }),
      );
    } catch (error) {
      _showSnack(usersProvider.extractErrorMessage(error), isError: true);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _showSnack('license_hub_recent_code_copied'.tr);
  }

  Future<void> _shareCode(String code) async {
    final message = 'license_hub_share_message'.trParams({'code': code});
    await SharePlus.instance.share(ShareParams(text: message));
  }

  Future<void> _revokePromoCode(Map<String, dynamic> promoCode) async {
    final usersProvider = context.read<UsersProvider>();
    final shouldRevoke = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('license_hub_revoke_confirm_title'.tr),
        content: Text(
          'license_hub_revoke_confirm_body'.trParams({
            'code': (promoCode['rawCode'] ?? promoCode['codePreview'] ?? '')
                .toString(),
          }),
          textDirection: _textDirection,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('license_hub_revoke_action'.tr),
          ),
        ],
      ),
    );

    if (shouldRevoke != true) return;

    try {
      final response = await usersProvider.revokePromoCode(
        (promoCode['id'] ?? '').toString(),
      );
      if (!mounted) return;
      _showSnack(
        'license_hub_revoke_success'.trParams({
          'count': (response['releasedCount'] ?? 0).toString(),
        }),
      );
    } catch (error) {
      _showSnack(usersProvider.extractErrorMessage(error), isError: true);
    }
  }

  Widget _buildNoExpiryNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.successColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: AppColors.successColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'license_hub_no_expiry_note'.tr,
              textDirection: _textDirection,
              style: AppTypography.of(context)
                  .bodySmall
                  .copyWith(color: AppColors.blackFontColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseExpiryCard(BuildContext context, UsersProvider usersProvider) {
    final expiresAt = usersProvider.licenseExpiresAt!;
    final days = usersProvider.licenseDaysRemaining ?? 0;
    final isExpiringSoon = days <= 30;
    final isExpired = days <= 0;
    final accentColor = isExpired
        ? Colors.red.shade700
        : isExpiringSoon
            ? Colors.orange.shade700
            : AppColors.successColor;
    final bgColor = isExpired
        ? Colors.red.shade50
        : isExpiringSoon
            ? Colors.orange.shade50
            : const Color(0xFFF0FFF4);

    // Format date as dd/MM/yyyy
    final formattedDate =
        '${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}';

    String subtitle;
    if (isExpired) {
      subtitle = 'license_hub_expired_banner'.tr;
    } else if (days == 1) {
      subtitle = 'license_hub_days_remaining_one'.tr;
    } else if (isExpiringSoon) {
      subtitle = 'license_hub_expiry_warning'.trParams({'days': days.toString()});
    } else {
      subtitle = 'license_hub_days_remaining'.trParams({'days': days.toString()});
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isExpired
                ? Icons.cancel_outlined
                : isExpiringSoon
                    ? Icons.warning_amber_rounded
                    : Icons.verified_outlined,
            color: accentColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'license_hub_expiry_label'.tr,
                  textDirection: _textDirection,
                  style: AppTypography.of(context)
                      .bodySmall
                      .copyWith(color: AppColors.hintTextColor, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  textDirection: TextDirection.ltr,
                  style: AppTypography.of(context)
                      .bodySmall
                      .copyWith(color: accentColor, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textDirection: _textDirection,
                  style: AppTypography.of(context)
                      .bodySmall
                      .copyWith(color: accentColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.of(context)
                  .pageHeading
                  .copyWith(color: accent, fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textDirection: _textDirection,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTypography.of(context)
                  .badgeLabel
                  .copyWith(color: AppColors.hintTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftPoolMiniStat({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.of(context).badgeCount.copyWith(color: accent),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            textDirection: _textDirection,
            style: AppTypography.of(context)
                .badgeLabel
                .copyWith(color: AppColors.hintTextColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(
    Map<String, dynamic> promoCode,
    UsersProvider usersProvider,
  ) {
    final isRevoked = (promoCode['status'] ?? '') == 'revoked';
    final rawCode = (promoCode['rawCode'] ?? '').toString();
    final hasRawCode = !isRevoked && rawCode.isNotEmpty;
    final displayCode =
        hasRawCode ? rawCode : (promoCode['codePreview'] ?? '').toString();
    final remainingUses = ((promoCode['remainingUses'] ?? 0) as num).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  displayCode,
                  textDirection: TextDirection.ltr,
                  style: AppTypography.of(context).listTileTitle.copyWith(
                        fontSize: 18,
                        color: hasRawCode
                            ? AppColors.buttonColor
                            : AppColors.blackFontColor,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isRevoked
                          ? AppColors.hintTextColor
                          : AppColors.successColor)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isRevoked
                      ? 'license_hub_code_status_revoked'.tr
                      : 'license_hub_code_status_active'.tr,
                  style: AppTypography.of(context).badgeLabel.copyWith(
                        color: isRevoked
                            ? AppColors.hintTextColor
                            : AppColors.successColor,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'license_hub_code_used'.trParams({
                  'count': (promoCode['usedCount'] ?? 0).toString(),
                }),
                textDirection: _textDirection,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: AppColors.hintTextColor),
              ),
              Text(
                'license_hub_code_remaining'.trParams({
                  'count': remainingUses.toString(),
                }),
                textDirection: _textDirection,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: AppColors.hintTextColor),
              ),
              Text(
                'license_hub_code_created'.trParams({
                  'date': _formatDate(promoCode['createdAt']),
                }),
                textDirection: _textDirection,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: AppColors.hintTextColor),
              ),
              Text(
                'license_hub_code_expiry'.trParams({
                  'date': promoCode['expiresAt'] == null
                      ? 'license_hub_date_not_set'.tr
                      : _formatDate(promoCode['expiresAt']),
                }),
                textDirection: _textDirection,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: AppColors.hintTextColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isRevoked && !hasRawCode)
                InfoIconButton(
                  message: 'license_hub_legacy_code_hidden'.tr,
                  color: AppColors.hintTextColor,
                ),
              if (hasRawCode)
                OutlinedButton.icon(
                  onPressed: () => _copyCode(rawCode),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text('license_hub_recent_code_copy'.tr),
                ),
              if (hasRawCode)
                OutlinedButton.icon(
                  onPressed: () => _shareCode(rawCode),
                  icon: const Icon(Icons.share, size: 18),
                  label: Text('license_hub_share_action'.tr),
                ),
              if (!isRevoked && remainingUses > 0)
                OutlinedButton(
                  onPressed: usersProvider.isPromoCodesLoading
                      ? null
                      : () => _revokePromoCode(promoCode),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  child: Text('license_hub_revoke_action'.tr),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<UsersProvider>();
    final balance = usersProvider.licenseBalanceSummary;
    final giftPool = usersProvider.giftPoolSummary;
    final promoCodes = usersProvider.myPromoCodes;
    final hasBalanceData = balance != null;
    final ownedCount = ((balance?['ownedCount'] ?? 0) as num).toInt();
    final reservedCount = ((balance?['reservedCount'] ?? 0) as num).toInt();
    final giftAvailable = ((giftPool?['availableCount'] ?? 0) as num).toInt();
    final giftContributed =
        ((giftPool?['lifetimeContributed'] ?? 0) as num).toInt();
    final giftConsumed = ((giftPool?['lifetimeConsumed'] ?? 0) as num).toInt();
    final licenseStatus =
        usersProvider.activeAccountUser?.licenseStatus ?? 'pending';

    return SoftPatternBackground(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          'license_hub_title'.tr,
          style: AppTypography.of(context)
              .appBarTitle
              .copyWith(color: AppColors.blackFontColor),
        ),
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              balance == null &&
              promoCodes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () =>
                usersProvider.loadPromoWorkspace(forceRefresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                if (hasBalanceData)
                  Row(
                    children: [
                      _buildSummaryTile(
                        label: 'license_hub_owned_count'.tr,
                        value: ownedCount.toString(),
                        accent: AppColors.buttonColor,
                      ),
                      const SizedBox(width: 10),
                      _buildSummaryTile(
                        label: 'license_hub_reserved_count'.tr,
                        value: reservedCount.toString(),
                        accent: AppColors.primaryPurple,
                      ),
                    ],
                  ),
                if (!hasBalanceData &&
                    usersProvider.promoWorkspaceError != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.lineColor),
                    ),
                    child: Text(
                      'license_hub_loading'.tr,
                      textDirection: _textDirection,
                      style: AppTypography.of(context)
                          .bodySmall
                          .copyWith(color: AppColors.hintTextColor),
                    ),
                  ),
                if (giftAvailable + giftContributed + giftConsumed > 0) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildGiftPoolMiniStat(
                        label: 'license_hub_gift_pool_balance'.tr,
                        value: giftAvailable.toString(),
                        accent: AppColors.successColor,
                      ),
                      _buildGiftPoolMiniStat(
                        label: 'license_hub_gift_pool_contributed_label'.tr,
                        value: giftContributed.toString(),
                        accent: AppColors.primaryPurple,
                      ),
                      _buildGiftPoolMiniStat(
                        label: 'license_hub_gift_pool_consumed_label'.tr,
                        value: giftConsumed.toString(),
                        accent: AppColors.hintTextColor,
                      ),
                    ],
                  ),
                ],
                if (licenseStatus != 'active') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warmSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'license_hub_status_pending'.tr,
                      textDirection: _textDirection,
                      style: AppTypography.of(context)
                          .bodySmall
                          .copyWith(color: AppColors.blackFontColor),
                    ),
                  ),
                ],
                // Show license expiry info when active
                if (licenseStatus == 'active') ...[
                  const SizedBox(height: 12),
                  usersProvider.licenseExpiresAt != null
                      ? _buildLicenseExpiryCard(context, usersProvider)
                      : _buildNoExpiryNotice(context),
                ],
                if (usersProvider.promoWorkspaceError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      usersProvider.promoWorkspaceError!,
                      textDirection: _textDirection,
                      style: AppTypography.of(context)
                          .inputError
                          .copyWith(color: Colors.red.shade700),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _buildCreateCodeSection(usersProvider, ownedCount),
                const SizedBox(height: 14),
                _buildGiftPoolSection(usersProvider, ownedCount),
                const SizedBox(height: 14),
                Text(
                  'license_hub_codes_title'.tr,
                  textDirection: _textDirection,
                  style: AppTypography.of(context).sectionTitle.copyWith(
                        color: AppColors.blackFontColor,
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 8),
                if (promoCodes.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.lineColor),
                    ),
                    child: Text(
                      'license_hub_no_codes'.tr,
                      textDirection: TextDirection.rtl,
                      style: AppTypography.of(context)
                          .bodySmall
                          .copyWith(color: AppColors.hintTextColor),
                    ),
                  )
                else
                  ...promoCodes.map(
                    (promoCode) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildPromoCard(promoCode, usersProvider),
                    ),
                  ),
                const SizedBox(height: 20),
                _buildBuyMoreSection(usersProvider),
              ],
            ),
          );
        },
      ),
    ));
  }

  Widget _buildCreateCodeSection(
    UsersProvider usersProvider,
    int ownedCount,
  ) {
    final canCreate = ownedCount > 0 && !usersProvider.isPromoCodesLoading;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'license_hub_create_title'.tr,
            textDirection: _textDirection,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: AppColors.blackFontColor, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _maxUsesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'license_hub_max_uses'.tr,
                    helperText: ownedCount > 0
                        ? 'license_hub_max_uses_helper'.trParams({
                            'max': ownedCount.toString(),
                          })
                        : 'license_hub_max_uses_zero'.tr,
                    helperMaxLines: 2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed:
                    canCreate ? () => _createPromoCode(ownedCount) : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  usersProvider.isPromoCodesLoading
                      ? 'license_hub_loading'.tr
                      : 'license_hub_create_action'.tr,
                ),
              ),
            ],
          ),
          if (_recentRawCode != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mintSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'license_hub_recent_code_title'.tr,
                    textDirection: _textDirection,
                    style: AppTypography.of(context).listTileTitle.copyWith(
                          color: AppColors.blackFontColor,
                          fontSize: 13,
                        ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _recentRawCode!,
                    textDirection: TextDirection.ltr,
                    style: AppTypography.of(context).listTileTitle.copyWith(
                          fontSize: 16,
                          color: AppColors.buttonColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copyCode(_recentRawCode!),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text('license_hub_recent_code_copy'.tr),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _shareCode(_recentRawCode!),
                        icon: const Icon(Icons.share, size: 16),
                        label: Text('license_hub_share_action'.tr),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGiftPoolSection(
    UsersProvider usersProvider,
    int ownedCount,
  ) {
    final canContribute = ownedCount > 0 && !usersProvider.isPromoCodesLoading;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lineColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            'license_hub_gift_pool_title'.tr,
            textDirection: _textDirection,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: AppColors.blackFontColor, fontSize: 15),
          ),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'license_hub_gift_pool_irreversible'.tr,
                textDirection: _textDirection,
                style: AppTypography.of(context).badgeLabel.copyWith(
                      color: AppColors.blackFontColor,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _giftContributionController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'license_hub_gift_pool_quantity'.tr,
                      helperText: 'license_hub_max_uses_helper'.trParams({
                        'max': ownedCount.toString(),
                      }),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: canContribute
                      ? () => _contributeToGiftPool(ownedCount)
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                  child: Text(
                    usersProvider.isPromoCodesLoading
                        ? 'license_hub_gift_pool_loading'.tr
                        : 'license_hub_gift_pool_action'.tr,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPurchaseCheckout() async {
    setState(() {
      _purchaseError = null;
    });

    _showPurchaseNotice(
      'license_activation_purchase_under_preparation'.tr,
      accent: const Color(0xFF8A5A12),
      icon: Icons.hourglass_top_rounded,
    );
  }

  Widget _buildApplePurchaseLinkCard({
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.14)),
          ),
          child: Text(
            'license_activation_purchase_apple_notice'.tr,
            textDirection: _textDirection,
            style: AppTypography.of(context).bodySecondary.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent,
                  height: 1.6,
                ),
          ),
        ),
        if (_purchaseNotice != null) ...[
          const SizedBox(height: 12),
          _buildPurchaseNotice(),
        ],
        if (_purchaseError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.errorColor.withValues(alpha: 0.24)),
            ),
            child: Text(
              _purchaseError!,
              textDirection: _textDirection,
              style: AppTypography.of(context)
                  .bodyDefault
                  .copyWith(color: AppColors.errorColor),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBuyMoreSection(UsersProvider usersProvider) {
    const accent = Color(0xFF5B3DA1);
    final tiers = [
      {
        'qty': 20,
        'titleKey': 'license_activation_bundle_20_title',
        'priceKey': 'license_activation_bundle_20_price'
      },
      {
        'qty': 100,
        'titleKey': 'license_activation_bundle_100_title',
        'priceKey': 'license_activation_bundle_100_price'
      },
      {
        'qty': 1000,
        'titleKey': 'license_activation_bundle_1000_title',
        'priceKey': 'license_activation_bundle_1000_price'
      },
      {
        'qty': 10000,
        'titleKey': 'license_activation_bundle_10000_title',
        'priceKey': 'license_activation_bundle_10000_price'
      },
    ];

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
                child: const Icon(Icons.shopping_cart_checkout_outlined,
                    color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'license_activation_purchase_title'.tr,
                  textDirection: _textDirection,
                  style: AppTypography.of(context).sectionTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackFontColor,
                      ),
                ),
              ),
              InfoIconButton(
                message: 'license_activation_purchase_body'.tr,
                color: accent.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_hidePurchaseBundlesForApple) ...[
            _buildApplePurchaseLinkCard(accent: accent),
          ] else ...[
            Text(
              'license_activation_purchase_pricing_label'.tr,
              textDirection: _textDirection,
              style: AppTypography.of(context).inputLabel.copyWith(
                    color: AppColors.blackFontColor,
                  ),
            ),
            const SizedBox(height: 10),
            ...tiers.map((tier) {
              final qty = tier['qty'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedPurchaseQuantity = qty),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedPurchaseQuantity == qty
                          ? accent.withValues(alpha: 0.12)
                          : accent.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedPurchaseQuantity == qty
                            ? accent
                            : accent.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (tier['titleKey'] as String).tr,
                            textDirection: _textDirection,
                            style: AppTypography.of(context)
                                .listTileTitle
                                .copyWith(color: AppColors.blackFontColor),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            (tier['priceKey'] as String).tr,
                            textDirection: TextDirection.ltr,
                            style: AppTypography.of(context)
                                .badgeLabel
                                .copyWith(fontSize: 14, color: accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_purchaseNotice != null) ...[
              const SizedBox(height: 10),
              _buildPurchaseNotice(),
            ],
            if (_purchaseError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.errorColor.withValues(alpha: 0.24)),
                ),
                child: Text(
                  _purchaseError!,
                  textDirection: _textDirection,
                  style: AppTypography.of(context)
                      .bodyDefault
                      .copyWith(color: AppColors.errorColor),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: usersProvider.isLicenseLoading
                    ? null
                    : _startPurchaseCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  disabledBackgroundColor: const Color(0xFFE8EBF1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  usersProvider.isLicenseLoading
                      ? 'license_activation_purchase_loading'.tr
                      : 'license_activation_purchase_action'.tr,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: usersProvider.isPromoCodesLoading
                    ? null
                    : () => _refreshPurchaseWorkspace(
                          showCheckingNotice: true,
                          showReviewNoticeWhenUnchanged: false,
                        ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('license_activation_purchase_refresh_balance'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
