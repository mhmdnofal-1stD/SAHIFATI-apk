import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/teacher_supervisions_services.dart';

/// Resolves the human-facing identity for a supervision owner payload.
///
/// `username` is the live primary identity. If it is missing or empty the
/// caller can fall back to `email` and finally `_id` for disambiguation.
/// Legacy display-only identity keys are intentionally ignored so old cached
/// data does not become a live identity source.
String resolveSupervisionOwnerName(
  Map<String, dynamic> owner, {
  required String fallback,
}) {
  final username = (owner['username'] as String?)?.trim();
  if (username != null && username.isNotEmpty) {
    return username;
  }
  final email = (owner['email'] as String?)?.trim();
  if (email != null && email.isNotEmpty) {
    return email;
  }
  final id = owner['_id'];
  if (id != null) {
    return '#$id';
  }
  return fallback;
}

class AddSupervisorScreen extends StatefulWidget {
  const AddSupervisorScreen({super.key});

  @override
  State<AddSupervisorScreen> createState() => _AddSupervisorScreenState();
}

class _AddSupervisorScreenState extends State<AddSupervisorScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final ImagePicker _imagePicker = ImagePicker();
  final TeacherSupervisionsService _supervisionsService =
      TeacherSupervisionsService();

  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  String? _extractCodeFromPayload(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      uri = null;
    }
    if (uri != null && uri.queryParameters['s'] != null) {
      return uri.queryParameters['s']!.trim().toUpperCase();
    }
    final upper = trimmed.toUpperCase();
    final regex = RegExp(r'^[0-9A-HJKMNP-TV-Z]{6,32}$');
    if (regex.hasMatch(upper)) {
      return upper;
    }
    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final code = _extractCodeFromPayload(barcode.rawValue);
      if (code != null) {
        await _handleCode(code);
        return;
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked == null) return;
      setState(() => _isProcessing = true);
      final BarcodeCapture? capture = kIsWeb
          ? await _scannerController.analyzeImage(picked.path)
          : await _scannerController.analyzeImage(File(picked.path).path);
      String? code;
      if (capture != null) {
        for (final b in capture.barcodes) {
          code = _extractCodeFromPayload(b.rawValue);
          if (code != null) break;
        }
      }
      if (code == null) {
        setState(() => _isProcessing = false);
        _showSnack('supervision_scan_no_code_in_image'.tr);
        return;
      }
      await _handleCode(code);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnack(e.toString());
    }
  }

  Future<void> _handleCode(String code) async {
    setState(() => _isProcessing = true);
    await _scannerController.stop();
    try {
      final preview = await _supervisionsService.previewByCode(code);
      if (!mounted) return;
      final shouldSend = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => _SupervisorPreviewSheet(preview: preview),
      );
      if (shouldSend != true) {
        await _scannerController.start();
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      final result = await _supervisionsService.scanByCode(code);
      if (!mounted) return;
      _showResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString());
      await _scannerController.start();
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final status = result['status'] as String? ?? '';
    final String titleKey;
    final String bodyKey;
    switch (status) {
      case 'request_created':
        titleKey = 'supervision_scan_result_created_title';
        bodyKey = 'supervision_scan_result_created_body';
        break;
      case 'request_pending':
        titleKey = 'supervision_scan_result_pending_title';
        bodyKey = 'supervision_scan_result_pending_body';
        break;
      case 'link_active':
        titleKey = 'supervision_scan_result_active_title';
        bodyKey = 'supervision_scan_result_active_body';
        break;
      default:
        titleKey = 'supervision_scan_result_unknown_title';
        bodyKey = 'supervision_scan_result_unknown_body';
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          titleKey.tr,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Color(0xFF132A4A),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          bodyKey.tr,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Color(0xFF374151),
            height: 1.55,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Get.back();
            },
            child: Text(
              'supervision_scan_result_dismiss'.tr,
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _switchCamera() async {
    await _scannerController.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'supervision_scan_screen_title'.tr,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'supervision_scan_torch_tooltip'.tr,
            onPressed: _toggleTorch,
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            ),
          ),
          IconButton(
            tooltip: 'supervision_scan_switch_camera_tooltip'.tr,
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x99000000),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'supervision_scan_hint'.tr,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _pickFromGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.photo_library_rounded,
                        color: Color(0xFF132A4A),
                      ),
                      label: Text(
                        'supervision_scan_pick_from_gallery'.tr,
                        style: const TextStyle(
                          color: Color(0xFF132A4A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupervisorPreviewSheet extends StatelessWidget {
  const _SupervisorPreviewSheet({required this.preview});

  final Map<String, dynamic> preview;

  @override
  Widget build(BuildContext context) {
    final owner = (preview['owner'] as Map?) ?? const {};
    final ownerMap = Map<String, dynamic>.from(owner);
    final ownerDisplayName = resolveSupervisionOwnerName(
      ownerMap,
      fallback: 'profile_unknown_user'.tr,
    );
    final email = (owner['email'] as String?) ?? '';
    final isSelf = preview['isSelf'] == true;
    final hasActiveLink = preview['hasActiveLink'] == true;
    final hasPendingRequest = preview['hasPendingRequest'] == true;

    final bool canSend = !isSelf && !hasActiveLink && !hasPendingRequest;
    String? warningKey;
    if (isSelf) {
      warningKey = 'supervision_preview_warning_self';
    } else if (hasActiveLink) {
      warningKey = 'supervision_preview_warning_active';
    } else if (hasPendingRequest) {
      warningKey = 'supervision_preview_warning_pending';
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEAE0),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF132A4A),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'supervision_preview_title'.tr,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ownerDisplayName,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Color(0xFF132A4A),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (warningKey != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFB45309),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warningKey.tr,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'supervision_preview_body'.tr,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x40132A4A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      'supervision_preview_cancel'.tr,
                      style: const TextStyle(
                        color: Color(0xFF132A4A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canSend
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF132A4A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                    ),
                    child: Text(
                      'supervision_preview_send'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
