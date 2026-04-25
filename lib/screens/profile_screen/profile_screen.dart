import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/users_provider.dart';
import '../../services/users_services.dart';
import '../../core/utils/file_download.dart';
import '../widgets/no_pop_scope.dart';
import 'add_supervisor_screen.dart';
import 'incoming_requests_screen.dart';

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
    _supervisionCodeFuture = _usersServices.getMySupervisionCode();
  }

  Future<void> _reload() async {
    setState(() {
      _supervisionCodeFuture = _usersServices.getMySupervisionCode();
    });
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

  Future<void> _handleShare(String shareUrl, String fullName) async {
    final bytes = await _captureCardImage();
    final shareText =
        '$fullName\n$shareUrl\n${'profile_qr_share_caption'.tr}';
    if (bytes == null) {
      await Share.share(shareText);
      return;
    }
    final file = XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: 'sahifati-supervision-qr.png',
    );
    await Share.shareXFiles(
      [file],
      text: shareText,
      subject: 'profile_qr_share_subject'.tr,
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    final bytes = await _captureCardImage();
    if (bytes == null) {
      _showSnack(context, 'profile_qr_save_failed'.tr);
      return;
    }
    if (kIsWeb) {
      await downloadBytes(bytes, 'sahifati-supervision-qr.png', 'image/png');
      _showSnack(context, 'profile_qr_save_started'.tr);
      return;
    }
    final file = XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: 'sahifati-supervision-qr.png',
    );
    await Share.shareXFiles(
      [file],
      text: 'profile_qr_save_share_hint'.tr,
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
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;

    return NoPopScope(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4ED),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F4ED),
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF132A4A)),
          title: Text(
            'profile_screen_title'.tr,
            style: const TextStyle(
              color: Color(0xFF132A4A),
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Tooltip(
                message: 'supervision_incoming_screen_title'.tr,
                child: IconButton(
                  onPressed: () => Get.to(
                    () => const IncomingRequestsScreen(),
                  ),
                  icon: const Icon(
                    Icons.inbox_outlined,
                    color: Color(0xFF132A4A),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Tooltip(
                message: 'profile_add_supervisor_tooltip'.tr,
                child: Material(
                  color: const Color(0xFF132A4A),
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
          ],
        ),
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
                        fullName: user?.fullName ?? '',
                        email: user?.email ?? '',
                      ),
                      const SizedBox(height: 18),
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
                          final fullName =
                              (data['fullName'] as String?)?.trim().isNotEmpty ==
                                      true
                                  ? data['fullName'] as String
                                  : (user?.fullName ?? '');
                          final shareUrl = data['shareUrl'] as String;
                          return _QrShareCard(
                            qrCardKey: _qrCardKey,
                            fullName: fullName,
                            shareUrl: shareUrl,
                            onShare: () => _handleShare(shareUrl, fullName),
                            onSave: () => _handleSave(context),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const _SupervisorIntroCard(),
                    ],
                  ),
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
    required this.fullName,
    required this.email,
  });

  final String fullName;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF132A4A),
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
                  fullName.isEmpty ? 'profile_unknown_user'.tr : fullName,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
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

class _QrShareCard extends StatelessWidget {
  const _QrShareCard({
    required this.qrCardKey,
    required this.fullName,
    required this.shareUrl,
    required this.onShare,
    required this.onSave,
  });

  final GlobalKey qrCardKey;
  final String fullName;
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
          Text(
            'profile_qr_card_title'.tr,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Color(0xFF132A4A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'profile_qr_card_subtitle'.tr,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          RepaintBoundary(
            key: qrCardKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: shareUrl,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF132A4A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF132A4A),
                    ),
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    fullName,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF132A4A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'sahifati.org',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: const Color(0xFF132A4A).withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
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
            backgroundColor: const Color(0xFF132A4A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: Icon(icon, color: Colors.white, size: 18),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
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
        icon: const Icon(Icons.download_rounded, color: Color(0xFF132A4A), size: 18),
        label: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF132A4A),
            fontWeight: FontWeight.w700,
          ),
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
        color: Color(0xFF132A4A),
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
            style: const TextStyle(
              color: Color(0xFF132A4A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF132A4A)),
            label: Text(
              'profile_qr_retry'.tr,
              style: const TextStyle(
                color: Color(0xFF132A4A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupervisorIntroCard extends StatelessWidget {
  const _SupervisorIntroCard();

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
              color: Color(0xFF132A4A),
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
                  style: const TextStyle(
                    color: Color(0xFF132A4A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'profile_supervisor_intro_body'.tr,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 13,
                    height: 1.55,
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
