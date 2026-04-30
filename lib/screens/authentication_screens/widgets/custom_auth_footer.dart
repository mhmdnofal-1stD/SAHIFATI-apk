import 'package:flutter/material.dart';
import '../../../core/typography/app_typography.dart';

class CustomAuthFooter extends StatelessWidget {
  const CustomAuthFooter({
    super.key,
    required this.actionText,
    required this.icon,
    required this.onTap,
  });

  final String actionText;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF132A4A),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0xFFD8DDE5)),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        actionText,
        style: AppTypography.of(context).buttonSecondary.copyWith(
              fontSize: 14,
              color: const Color(0xFF132A4A),
            ),
      ),
    );
  }
}
