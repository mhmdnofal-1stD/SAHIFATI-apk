import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/constants/colors.dart';
import '../core/constants/fonts.dart';

/// A global mid-session loading overlay that can be shown from anywhere.
///
/// Usage:
///   AppProgressOverlay.show('جاري تحميل التقييمات...', progress: 0.4);
///   AppProgressOverlay.hide();
///   AppProgressOverlay.showUntilDone(future, message: 'جاري التحديث...');
class AppProgressOverlay extends GetxController {
  static AppProgressOverlay get _ctrl {
    if (!Get.isRegistered<AppProgressOverlay>()) {
      Get.put(AppProgressOverlay(), permanent: true);
    }
    return Get.find<AppProgressOverlay>();
  }

  final RxBool _visible = false.obs;
  final RxString _message = ''.obs;
  final RxnDouble _progress = RxnDouble(null);

  bool get isVisible => _visible.value;
  String get message => _message.value;
  double? get progress => _progress.value;

  /// Show the overlay. Pass a [progress] between 0.0 and 1.0 to show a
  /// determinate bar; omit it for an indeterminate spinner.
  static void show(String message, {double? progress}) {
    final ctrl = _ctrl;
    ctrl._message.value = message;
    ctrl._progress.value = progress;
    ctrl._visible.value = true;
  }

  /// Update just the message and/or progress while the overlay is already
  /// visible.
  static void updateStep(String message, {double? progress}) {
    final ctrl = _ctrl;
    ctrl._message.value = message;
    ctrl._progress.value = progress;
  }

  /// Hide the overlay.
  static void hide() => _ctrl._visible.value = false;

  /// Show the overlay for the duration of [future], then hide it.
  static Future<T> showUntilDone<T>(
    Future<T> future, {
    required String message,
    double? initialProgress,
  }) async {
    show(message, progress: initialProgress);
    try {
      return await future;
    } finally {
      hide();
    }
  }

  @override
  void onClose() {
    _visible.value = false;
    super.onClose();
  }
}

/// Wraps any widget tree and shows the overlay on top when active.
/// Place this in [GetMaterialApp.builder].
class AppProgressOverlayWrapper extends StatelessWidget {
  const AppProgressOverlayWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    AppProgressOverlay._ctrl; // ensure registered
    return Stack(
      children: [
        child,
        Obx(() {
          final ctrl = AppProgressOverlay._ctrl;
          if (!ctrl.isVisible) {
            return const SizedBox.shrink();
          }
          return _OverlaySheet(
            message: ctrl.message,
            progress: ctrl.progress,
          );
        }),
      ],
    );
  }
}

class _OverlaySheet extends StatelessWidget {
  const _OverlaySheet({required this.message, this.progress});

  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : AppColors.backgroundColor;
    final surface = isDark ? const Color(0xFF252525) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.blackFontColor;
    final barColor = isDark ? AppColors.brandAccent : AppColors.buttonColor;
    final barBg = isDark ? const Color(0xFF2E2E2E) : AppColors.lineColor;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: 1.0,
      child: Container(
        color: bg.withValues(alpha: 0.72),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (progress == null)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                )
              else
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: barBg,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                      Center(
                        child: Text(
                          '${((progress ?? 0) * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            fontFamily: AppFonts.primaryFont,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontFamily: AppFonts.primaryFont,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
