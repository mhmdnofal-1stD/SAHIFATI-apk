import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/assets.dart';
import '../../core/constants/colors.dart';
import '../../providers/users_provider.dart';
import '../../services/users_services.dart';
import '../../core/typography/app_typography.dart';
import '../../core/utils/file_download.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/global_drawer.dart';
import '../widgets/info_icon_button.dart';
import 'add_supervisor_screen.dart';
import 'profile_details_form.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey _qrCardKey = GlobalKey();
  final UsersServices _usersServices = UsersServices();

  Future<Map<String, dynamic>>? _supervisionCodeFuture;

  @override
  void initState() {
    super.initState();
    _supervisionCodeFuture = _loadInitialSupervisionCode();
  }

  Future<Map<String, dynamic>> _loadInitialSupervisionCode() async {
    final cached = await _usersServices.getCachedMySupervisionCode();
    if (cached != null) {
      unawaited(_refreshSupervisionCodeInBackground());
      return cached;
    }

    return _usersServices.getMySupervisionCode();
  }

  Future<void> _refreshSupervisionCodeInBackground() async {
    try {
      final fresh = await _usersServices.getMySupervisionCode();
      if (!mounted) {
        return;
      }

      setState(() {
        _supervisionCodeFuture = Future.value(fresh);
      });
    } catch (error) {
      debugPrint('Supervision code background refresh skipped: $error');
    }
  }

  Future<void> _reload() async {
    try {
      final fresh = await _usersServices.getMySupervisionCode();
      if (!mounted) {
        return;
      }

      setState(() {
        _supervisionCodeFuture = Future.value(fresh);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnack(context, error.toString());
    }
  }

  Future<Uint8List?> _captureCardImage() async {
    final boundary =
        _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _handleShare(String shareUrl, String username) async {
    final bytes = await _captureCardImage();
    final shareText = '$username\n${'profile_qr_share_caption'.tr}\n$shareUrl';
    if (bytes == null) {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'profile_qr_share_subject'.tr,
        ),
      );
      return;
    }
    final file = XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: 'sahifati-supervision-qr.png',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: shareText,
        subject: 'profile_qr_share_subject'.tr,
      ),
    );
  }

  Future<void> _handleSave() async {
    final bytes = await _captureCardImage();
    if (!mounted) {
      return;
    }

    if (bytes == null) {
      _showSnack(context, 'profile_qr_save_failed'.tr);
      return;
    }
    if (kIsWeb) {
      await downloadBytes(bytes, 'sahifati-supervision-qr.png', 'image/png');
      if (!mounted) {
        return;
      }

      _showSnack(context, 'profile_qr_save_started'.tr);
      return;
    }
    final file = XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: 'sahifati-supervision-qr.png',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: 'profile_qr_save_share_hint'.tr,
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleAddSupervisor() {
    Get.to(() => const AddSupervisorScreen());
  }

  @override
  Widget build(BuildContext context) {
    final usersProvider = context.watch<UsersProvider>();
    final user = usersProvider.selectedUser;
    final isViewingStudent = usersProvider.hasPushedSelectedUser;
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4ED),
        elevation: 0,
        centerTitle: true,
        leading: CustomBackButton(
          onPressed: () {
            context.read<UsersProvider>().popSelectedUser();
            Navigator.of(context).maybePop();
          },
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryPurple),
        title: Text(
          'profile_screen_title'.tr,
          style: AppTypography.of(context)
              .appBarTitle
              .copyWith(color: AppColors.primaryPurple),
        ),
        actions: isViewingStudent
            ? const []
            : [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Tooltip(
                    message: 'profile_add_supervisor_tooltip'.tr,
                    child: Material(
                      color: AppColors.primaryPurple,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _handleAddSupervisor,
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.add_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      if ((Get.locale?.languageCode ?? 'ar') == 'ar') {
                        Scaffold.of(ctx).openDrawer();
                      } else {
                        Scaffold.of(ctx).openEndDrawer();
                      }
                    },
                  ),
                ),
              ],
      ),
      drawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
          ? const GlobalDrawer()
          : null,
      endDrawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
          ? null
          : const GlobalDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 24,
              12,
              isCompact ? 16 : 24,
              24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileIdentityHeader(
                      username: user?.username ?? user?.email ?? '',
                      email: user?.email ?? '',
                      licenseStatus: usersProvider.selectedUser?.licenseStatus,
                      licenseGrantedAt: usersProvider.licenseGrantedAt,
                    ),
                    const SizedBox(height: 18),
                    if (!isViewingStudent) ...[
                      FutureBuilder<Map<String, dynamic>>(
                        future: _supervisionCodeFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const _QrCardLoading();
                          }
                          if (snapshot.hasError) {
                            return _QrCardError(
                              message: snapshot.error.toString(),
                              onRetry: _reload,
                            );
                          }
                          final data = snapshot.data!;
                          final username = (data['username'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? data['username'] as String
                              : (user?.username ?? user?.email ?? '');
                          final shareUrl = data['shareUrl'] as String;
                          return _QrShareCard(
                            qrCardKey: _qrCardKey,
                            username: username,
                            shareUrl: shareUrl,
                            onShare: () => _handleShare(shareUrl, username),
                            onSave: _handleSave,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _SupervisorIntroCard(
                        onAddSupervisor: _handleAddSupervisor,
                      ),
                      const SizedBox(height: 16),
                    ],
                    const ProfileDetailsForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileIdentityHeader extends StatelessWidget {
  const _ProfileIdentityHeader({
    required this.username,
    required this.email,
    this.licenseStatus,
    this.licenseGrantedAt,
  });

  final String username;
  final String email;
  final String? licenseStatus;
  final DateTime? licenseGrantedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26132A4A),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username.isEmpty ? 'profile_unknown_user'.tr : username,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.of(context)
                      .userDisplayName
                      .copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textDirection: TextDirection.ltr,
                  style: AppTypography.of(context)
                      .bodySecondary
                      .copyWith(color: Colors.white.withValues(alpha: 0.78)),
                ),
                if (licenseStatus == 'active') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Colors.white.withValues(alpha: 0.88),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        licenseGrantedAt != null
                            ? '${'license_granted_at_label'.tr}: ${licenseGrantedAt!.day.toString().padLeft(2, '0')}/${licenseGrantedAt!.month.toString().padLeft(2, '0')}/${licenseGrantedAt!.year}'
                            : 'license_hub_status_active'.tr,
                        textDirection: TextDirection.rtl,
                        style: AppTypography.of(context).bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrShareCard extends StatelessWidget {
  const _QrShareCard({
    required this.qrCardKey,
    required this.username,
    required this.shareUrl,
    required this.onShare,
    required this.onSave,
  });

  final GlobalKey qrCardKey;
  final String username;
  final String shareUrl;
  final Future<void> Function() onShare;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7DFD2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'profile_qr_card_title'.tr,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.of(context)
                      .sectionTitle
                      .copyWith(color: AppColors.primaryPurple),
                ),
              ),
              InfoIconButton(
                message: 'profile_qr_card_subtitle'.tr,
                color: AppColors.mutedText,
              ),
            ],
          ),
          const SizedBox(height: 14),
          RepaintBoundary(
            key: qrCardKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          QrImageView(
                            data: shareUrl,
                            version: QrVersions.auto,
                            size: 240,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.primaryPurple,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.primaryPurple,
                            ),
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                          ),
                          IgnorePointer(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 108),
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    Assets.logoSvg,
                                    width: 44,
                                    height: 44,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.primaryPurple,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QrActionButton(
                  icon: Icons.ios_share_rounded,
                  label: 'profile_qr_action_share'.tr,
                  primary: true,
                  onTap: onShare,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QrActionButton(
                  icon: Icons.download_rounded,
                  label: 'profile_qr_action_save'.tr,
                  primary: false,
                  onTap: onSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrActionButton extends StatelessWidget {
  const _QrActionButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool primary;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => onTap(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: Icon(icon, color: Colors.white, size: 18),
          label: Text(
            label,
            style: AppTypography.of(context)
                .buttonPrimary
                .copyWith(color: Colors.white),
          ),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => onTap(),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0x40132A4A)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.download_rounded,
            color: AppColors.primaryPurple, size: 18),
        label: Text(
          label,
          style: AppTypography.of(context)
              .buttonSecondary
              .copyWith(color: AppColors.primaryPurple),
        ),
      ),
    );
  }
}

class _QrCardLoading extends StatelessWidget {
  const _QrCardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7DFD2)),
      ),
      child: const CircularProgressIndicator(
        color: AppColors.primaryPurple,
      ),
    );
  }
}

class _QrCardError extends StatelessWidget {
  const _QrCardError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7DFD2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_tethering_error_rounded,
            color: Color(0xFFB13030),
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            'profile_qr_load_failed'.tr,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context)
                .sectionTitle
                .copyWith(color: AppColors.primaryPurple),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.of(context)
                .bodySecondary
                .copyWith(color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.primaryPurple),
            label: Text(
              'profile_qr_retry'.tr,
              style: AppTypography.of(context)
                  .buttonSecondary
                  .copyWith(color: AppColors.primaryPurple),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupervisorIntroCard extends StatelessWidget {
  const _SupervisorIntroCard({
    required this.onAddSupervisor,
  });

  final VoidCallback onAddSupervisor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9E2D6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFEAE0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'profile_supervisor_intro_title'.tr,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.of(context)
                      .listTileTitle
                      .copyWith(color: AppColors.primaryPurple),
                ),
                const SizedBox(height: 6),
                Text(
                  'profile_supervisor_intro_body'.tr,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.of(context)
                      .bodySecondary
                      .copyWith(color: const Color(0xFF4B5563)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onAddSupervisor,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x40132A4A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primaryPurple,
                      size: 18,
                    ),
                    label: Text(
                      'profile_add_supervisor_tooltip'.tr,
                      style: AppTypography.of(context)
                          .buttonSecondary
                          .copyWith(color: AppColors.primaryPurple),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
