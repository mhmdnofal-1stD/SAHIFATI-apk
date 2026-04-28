import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../providers/users_provider.dart';

class MyLicensesScreen extends StatefulWidget {
  const MyLicensesScreen({super.key});

  @override
  State<MyLicensesScreen> createState() => _MyLicensesScreenState();
}

class _MyLicensesScreenState extends State<MyLicensesScreen> {
  late final Future<void> _loadFuture;
  int _selectedMaxUses = 1;
  final TextEditingController _giftContributionController =
      TextEditingController(text: '1');
  String? _recentRawCode;
  String? _inlineMessage;

  @override
  void initState() {
    super.initState();
    _loadFuture = _bootstrap();
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

  Future<void> _createPromoCode() async {
    final usersProvider = context.read<UsersProvider>();

    setState(() {
      _inlineMessage = null;
    });

    try {
      final createdPromo = await usersProvider.createPromoCode(
        maxUses: _selectedMaxUses,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recentRawCode = createdPromo['rawCode'] as String?;
        _inlineMessage = 'license_hub_create_success'.trParams({
          'count': _selectedMaxUses.toString(),
        });
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inlineMessage = usersProvider.extractErrorMessage(error);
      });
    }
  }

  Future<void> _contributeToGiftPool() async {
    final usersProvider = context.read<UsersProvider>();
    final ownedCount =
        ((usersProvider.licenseBalanceSummary?['ownedCount'] ?? 0) as num)
            .toInt();
    final quantity = int.tryParse(_giftContributionController.text.trim()) ?? 0;

    setState(() {
      _inlineMessage = null;
    });

    if (quantity < 1 || quantity > ownedCount) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inlineMessage = 'license_hub_gift_pool_not_enough'.tr;
      });
      return;
    }

    try {
      final response = await usersProvider.contributeToGiftPool(
        quantity: quantity,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _inlineMessage = 'license_hub_gift_pool_success'.trParams({
          'count': (response['quantityContributed'] ?? quantity).toString(),
        });
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inlineMessage = usersProvider.extractErrorMessage(error);
      });
    }
  }

  Future<void> _copyRecentCode() async {
    if (_recentRawCode == null || _recentRawCode!.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: _recentRawCode!));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('license_hub_recent_code_copied'.tr),
      ),
    );
  }

  Future<void> _revokePromoCode(Map<String, dynamic> promoCode) async {
    final usersProvider = context.read<UsersProvider>();
    final shouldRevoke = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('license_hub_revoke_confirm_title'.tr),
        content: Text(
          'license_hub_revoke_confirm_body'.trParams({
            'code': (promoCode['codePreview'] ?? '').toString(),
          }),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('license_hub_revoke_action'.tr),
          ),
        ],
      ),
    );

    if (shouldRevoke != true) {
      return;
    }

    try {
      final response = await usersProvider.revokePromoCode(
        (promoCode['id'] ?? '').toString(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _inlineMessage = 'license_hub_revoke_success'.trParams({
          'count': (response['releasedCount'] ?? 0).toString(),
        });
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inlineMessage = usersProvider.extractErrorMessage(error);
      });
    }
  }

  @override
  void dispose() {
    _giftContributionController.dispose();
    super.dispose();
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
                child: Text(
                  (promoCode['codePreview'] ?? '').toString(),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackFontColor,
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
                  'count': (promoCode['remainingUses'] ?? 0).toString(),
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
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: isRevoked || usersProvider.isPromoCodesLoading
                  ? null
                  : () => _revokePromoCode(promoCode),
              child: Text('license_hub_revoke_action'.tr),
            ),
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
    final licenseStatus =
        usersProvider.selectedUser?.licenseStatus ?? 'pending';

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
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
                      value: ((balance?['ownedCount'] ?? 0) as num).toString(),
                      accent: AppColors.buttonColor,
                    ),
                    const SizedBox(width: 12),
                    _buildSummaryTile(
                      label: 'license_hub_reserved_count'.tr,
                      value:
                          ((balance?['reservedCount'] ?? 0) as num).toString(),
                      accent: AppColors.primaryPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
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
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildSummaryTile(
                            label: 'license_hub_gift_pool_available'.trParams({
                              'count':
                                  ((giftPool?['availableCount'] ?? 0) as num)
                                      .toString(),
                            }),
                            value: ((giftPool?['availableCount'] ?? 0) as num)
                                .toString(),
                            accent: AppColors.buttonColor,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryTile(
                            label:
                                'license_hub_gift_pool_contributed'.trParams({
                              'count': ((giftPool?['lifetimeContributed'] ?? 0)
                                      as num)
                                  .toString(),
                            }),
                            value:
                                ((giftPool?['lifetimeContributed'] ?? 0) as num)
                                    .toString(),
                            accent: AppColors.primaryPurple,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryTile(
                            label: 'license_hub_gift_pool_consumed'.trParams({
                              'count':
                                  ((giftPool?['lifetimeConsumed'] ?? 0) as num)
                                      .toString(),
                            }),
                            value: ((giftPool?['lifetimeConsumed'] ?? 0) as num)
                                .toString(),
                            accent: AppColors.successColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _giftContributionController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: 'license_hub_gift_pool_quantity'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: usersProvider.isPromoCodesLoading
                            ? null
                            : _contributeToGiftPool,
                        child: Text(
                          usersProvider.isPromoCodesLoading
                              ? 'license_hub_gift_pool_loading'.tr
                              : 'license_hub_gift_pool_action'.tr,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
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
                      DropdownButtonFormField<int>(
                        initialValue: _selectedMaxUses,
                        decoration: InputDecoration(
                          labelText: 'license_hub_max_uses'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        items: List.generate(
                          10,
                          (index) => DropdownMenuItem<int>(
                            value: index + 1,
                            child: Text((index + 1).toString()),
                          ),
                        ),
                        onChanged: usersProvider.isPromoCodesLoading
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedMaxUses = value;
                                });
                              },
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: usersProvider.isPromoCodesLoading
                            ? null
                            : _createPromoCode,
                        child: Text(
                          usersProvider.isPromoCodesLoading
                              ? 'license_hub_loading'.tr
                              : 'license_hub_create_action'.tr,
                        ),
                      ),
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
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: _copyRecentCode,
                                  child:
                                      Text('license_hub_recent_code_copy'.tr),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_inlineMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warmSurface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _inlineMessage!,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppFonts.primaryFont,
                        color: AppColors.blackFontColor,
                      ),
                    ),
                  ),
                ],
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
}
