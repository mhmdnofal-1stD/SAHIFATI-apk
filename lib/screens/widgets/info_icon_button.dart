import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A small ℹ️ icon that shows [message] in a popup dialog on tap.
/// Place it next to an interactive button to surface contextual help
/// without cluttering the visible UI.
class InfoIconButton extends StatelessWidget {
  const InfoIconButton({
    super.key,
    required this.message,
    this.color,
    this.size = 18.0,
  });

  final String message;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.info_outline_rounded,
        size: size,
        color: color ?? const Color(0xFF9AA3B2),
      ),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: size + 10,
        minHeight: size + 10,
      ),
      visualDensity: VisualDensity.compact,
      tooltip: 'info'.tr,
      onPressed: () => _show(context),
    );
  }

  void _show(BuildContext context) {
    final isRtl = (Get.locale?.languageCode ?? 'ar') == 'ar';
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.65),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('ok'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
