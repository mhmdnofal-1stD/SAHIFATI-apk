import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';

class MyLicensesScreen extends StatefulWidget {
  const MyLicensesScreen({super.key});

  @override
  State<MyLicensesScreen> createState() => _MyLicensesScreenState();
}

class _MyLicensesScreenState extends State<MyLicensesScreen> {
  late final Future<void> _loadFuture;
  final TextEditingController _maxUsesController =
      TextEditingController(text: '1');
  final TextEditingController _giftContributionController =
      TextEditingController(text: '1');
  String? _recentRawCode;

  @override
  void initState() {
    super.initState();
    _loadFuture = _bootstrap();
  }

  @override
  void dispose() {
    _maxUsesController.dispose();
    _giftContributionController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final usersProvider = context.read<UsersProvider>();
    if (usersProvider.selectedUser == null) {
      final isLoggedIn = await usersProvider.tryAutoLogin();
      if (!isLoggedIn || usersProvider.selectedUser == null) {
        if (mounted) {
          Get.offAllNamed('/login');
        }
        return;
      }
    }
    await usersProvider.loadPromoWorkspace(forceRefresh: true);
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
          content: Text(message, textDirection: TextDirection.rtl),
          backgroundColor: isError ? Colors.red.shade700 : null,
          behavior: SnackBarBehavior.floating,
        ),
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
      final createdPromo =
          await usersProvider.createPromoCode(maxUses: value);
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
    final quantity =
        int.tryParse(_giftContributionController.text.trim()) ?? 0;

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
          textDirection: TextDirection.rtl,
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
    final message =
        'license_hub_share_message'.trParams({'code': code});
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
            'code': (promoCode['rawCode'] ??
                    promoCode['codePreview'] ??
                    '')
                .toString(),
          }),
          textDirection: TextDirection.rtl,
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

  Widget _buildSummaryTile({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                color: AppColors.hintTextColor,
              ),
            ),
          ],
        ),
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
    final displayCode = hasRawCode
        ? rawCode
        : (promoCode['codePreview'] ?? '').toString();
    final remainingUses =
        ((promoCode['remainingUses'] ?? 0) as num).toInt();

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
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontWeight: FontWeight.w700,
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
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppFonts.primaryFont,
                  color: AppColors.hintTextColor,
                ),
              ),
              Text(
                'license_hub_code_remaining'.trParams({
                  'count': remainingUses.toString(),
                }),
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppFonts.primaryFont,
                  color: AppColors.hintTextColor,
                ),
              ),
              Text(
                'license_hub_code_created'.trParams({
                  'date': _formatDate(promoCode['createdAt']),
                }),
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppFonts.primaryFont,
                  color: AppColors.hintTextColor,
                ),
              ),
              Text(
                'license_hub_code_expiry'.trParams({
                  'date': promoCode['expiresAt'] == null
                      ? 'license_hub_date_not_set'.tr
                      : _formatDate(promoCode['expiresAt']),
                }),
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppFonts.primaryFont,
                  color: AppColors.hintTextColor,
                ),
              ),
            ],
          ),
          if (!isRevoked && !hasRawCode) ...[
            const SizedBox(height: 10),
            Text(
              'license_hub_legacy_code_hidden'.tr,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                color: AppColors.hintTextColor,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
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
    final ownedCount = ((balance?['ownedCount'] ?? 0) as num).toInt();
    final reservedCount = ((balance?['reservedCount'] ?? 0) as num).toInt();
    final giftAvailable =
        ((giftPool?['availableCount'] ?? 0) as num).toInt();
    final giftContributed =
        ((giftPool?['lifetimeContributed'] ?? 0) as num).toInt();
    final giftConsumed =
        ((giftPool?['lifetimeConsumed'] ?? 0) as num).toInt();
    final licenseStatus =
        usersProvider.selectedUser?.licenseStatus ?? 'pending';

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          'license_hub_title'.tr,
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            fontWeight: FontWeight.w700,
            color: AppColors.blackFontColor,
          ),
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
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'license_hub_subtitle'.tr,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    color: AppColors.hintTextColor,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF153B63), Color(0xFF0A7C62)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    licenseStatus == 'active'
                        ? 'license_hub_status_active'.tr
                        : 'license_hub_status_pending'.tr,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _buildSummaryTile(
                      label: 'license_hub_owned_count'.tr,
                      value: ownedCount.toString(),
                      accent: AppColors.buttonColor,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryTile(
                      label: 'license_hub_reserved_count'.tr,
                      value: reservedCount.toString(),
                      accent: AppColors.primaryPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildSummaryTile(
                      label: 'license_hub_gift_pool_balance'.tr,
                      value: giftAvailable.toString(),
                      accent: AppColors.successColor,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryTile(
                      label: 'license_hub_gift_pool_contributed_label'.tr,
                      value: giftContributed.toString(),
                      accent: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryTile(
                      label: 'license_hub_gift_pool_consumed_label'.tr,
                      value: giftConsumed.toString(),
                      accent: AppColors.hintTextColor,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _buildCreateCodeSection(usersProvider, ownedCount),
                const SizedBox(height: 22),
                _buildGiftPoolSection(usersProvider, ownedCount),
                const SizedBox(height: 22),
                Text(
                  'license_hub_codes_title'.tr,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.blackFontColor,
                  ),
                ),
                const SizedBox(height: 14),
                if (promoCodes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.lineColor),
                    ),
                    child: Text(
                      'license_hub_no_codes'.tr,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        color: AppColors.hintTextColor,
                      ),
                    ),
                  )
                else
                  ...promoCodes.map(
                    (promoCode) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPromoCard(promoCode, usersProvider),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateCodeSection(
    UsersProvider usersProvider,
    int ownedCount,
  ) {
    final canCreate = ownedCount > 0 && !usersProvider.isPromoCodesLoading;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'license_hub_create_title'.tr,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppFonts.primaryFont,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.blackFontColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'license_hub_create_body'.tr,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppFonts.primaryFont,
              color: AppColors.hintTextColor,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _maxUsesController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'license_hub_max_uses'.tr,
              helperText: 'license_hub_max_uses_helper'.trParams({
                'max': ownedCount.toString(),
              }),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: canCreate ? () => _createPromoCode(ownedCount) : null,
            child: Text(
              usersProvider.isPromoCodesLoading
                  ? 'license_hub_loading'.tr
                  : 'license_hub_create_action'.tr,
            ),
          ),
          if (ownedCount == 0) ...[
            const SizedBox(height: 8),
            Text(
              'license_hub_max_uses_zero'.tr,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                color: AppColors.hintTextColor,
                fontSize: 12,
              ),
            ),
          ],
          if (_recentRawCode != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mintSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'license_hub_recent_code_title'.tr,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blackFontColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _recentRawCode!,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.buttonColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copyCode(_recentRawCode!),
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text('license_hub_recent_code_copy'.tr),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _shareCode(_recentRawCode!),
                        icon: const Icon(Icons.share, size: 18),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'license_hub_gift_pool_title'.tr,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppFonts.primaryFont,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.blackFontColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'license_hub_gift_pool_body'.tr,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: AppFonts.primaryFont,
              color: AppColors.hintTextColor,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warmSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'license_hub_gift_pool_irreversible'.tr,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                color: AppColors.blackFontColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _giftContributionController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'license_hub_gift_pool_quantity'.tr,
              helperText: 'license_hub_max_uses_helper'.trParams({
                'max': ownedCount.toString(),
              }),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed:
                canContribute ? () => _contributeToGiftPool(ownedCount) : null,
            child: Text(
              usersProvider.isPromoCodesLoading
                  ? 'license_hub_gift_pool_loading'.tr
                  : 'license_hub_gift_pool_action'.tr,
            ),
          ),
        ],
      ),
    );
  }
}
