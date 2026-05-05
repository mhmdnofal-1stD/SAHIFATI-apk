import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A small ℹ️ icon that shows [message] in a popup dialog on tap.
/// Place it next to an interactive button to surface contextual help
/// without cluttering the visible UI.
class InfoIconButton extends StatelessWidget {
  const InfoIconButton({
    super.key,
    required this.message,
    this.title,
    this.color,
    this.size = 18.0,
  });

  final String message;
  final String? title;
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
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          title: title == null
              ? null
              : Text(
                  title!,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF132A4A),
                  ),
                ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              message,
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
              style: const TextStyle(fontSize: 15, height: 1.75),
            ),
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
