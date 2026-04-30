import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
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
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            style: AppTypography.of(context)
                .badgeCount
                .copyWith(color: accent),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            textDirection: TextDirection.rtl,
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
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: AppColors.hintTextColor),
              ),
              Text(
                'license_hub_code_remaining'.trParams({
                  'count': remainingUses.toString(),
                }),
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: AppColors.hintTextColor),
              ),
              Text(
                'license_hub_code_created'.trParams({
                  'date': _formatDate(promoCode['createdAt']),
                }),
                textDirection: TextDirection.rtl,
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
                textDirection: TextDirection.rtl,
                style: AppTypography.of(context)
                    .bodySecondary
                    .copyWith(color: AppColors.hintTextColor),
              ),
            ],
          ),
          if (!isRevoked && !hasRawCode) ...[
            const SizedBox(height: 10),
            Text(
              'license_hub_legacy_code_hidden'.tr,
              textDirection: TextDirection.rtl,
              style: AppTypography.of(context)
                  .bodySmall
                  .copyWith(color: AppColors.hintTextColor),
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
                      textDirection: TextDirection.rtl,
                      style: AppTypography.of(context)
                          .bodySmall
                          .copyWith(color: AppColors.blackFontColor),
                    ),
                  ),
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
                      textDirection: TextDirection.rtl,
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
                  textDirection: TextDirection.rtl,
                  style: AppTypography.of(context)
                      .sectionTitle
                      .copyWith(
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
            textDirection: TextDirection.rtl,
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
                    textDirection: TextDirection.rtl,
                    style: AppTypography.of(context)
                        .listTileTitle
                        .copyWith(
                          color: AppColors.blackFontColor,
                          fontSize: 13,
                        ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _recentRawCode!,
                    textDirection: TextDirection.ltr,
                    style: AppTypography.of(context)
                        .listTileTitle
                        .copyWith(
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
            textDirection: TextDirection.rtl,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: AppColors.blackFontColor, fontSize: 15),
          ),
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'license_hub_gift_pool_irreversible'.tr,
                textDirection: TextDirection.rtl,
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
                      helperText:
                          'license_hub_max_uses_helper'.trParams({
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
}
