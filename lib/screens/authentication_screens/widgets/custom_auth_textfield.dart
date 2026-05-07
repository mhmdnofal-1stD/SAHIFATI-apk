import 'package:flutter/material.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/core/typography/app_typography.dart';

class CustomAuthenticationTextField extends StatefulWidget {
  const CustomAuthenticationTextField({
    super.key,
    this.hintText,
    this.semanticLabel,
    this.leadingIcon,
    required this.obscureText,
    required this.textEditingController,
    required this.borderColor,
    this.borderWidth,
    this.isSettings,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.focusNode,
    this.onSubmitted,
  });

  final String? hintText;
  final String? semanticLabel;
  final IconData? leadingIcon;
  final bool obscureText;
  final TextEditingController textEditingController;
  final Color borderColor;
  final double? borderWidth;
  final bool? isSettings;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CustomAuthenticationTextField> createState() =>
      _CustomAuthenticationTextFieldState();
}

class _CustomAuthenticationTextFieldState
    extends State<CustomAuthenticationTextField> {
  bool showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.isSettings == null || widget.isSettings == false
          ? const EdgeInsets.only(bottom: 6)
          : const EdgeInsets.only(bottom: 12, top: 6),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              width: widget.borderWidth ?? 1.0, color: widget.borderColor),
          color: AppColors.panelColor,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D1D6652),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Semantics(
              textField: true,
              label: widget.semanticLabel,
              child: TextField(
                  textAlign: TextAlign.left,
                  controller: widget.textEditingController,
                  focusNode: widget.focusNode,
                  keyboardType: widget.keyboardType,
                  autofillHints: widget.autofillHints,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  enableSuggestions: !widget.obscureText,
                  autocorrect: !widget.obscureText,
                  obscureText: widget.obscureText && !showPassword,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    prefixIcon: widget.leadingIcon == null
                        ? null
                        : Icon(
                            widget.leadingIcon,
                            color: AppColors.mutedText,
                            size: 20,
                          ),
                    suffixIcon: widget.obscureText
                        ? IconButton(
                            icon: !showPassword
                                ? const Icon(
                                    Icons.visibility,
                                    color: AppColors.mutedText,
                                  )
                                : const Icon(
                                    Icons.visibility_off,
                                    color: AppColors.mutedText,
                                  ),
                            onPressed: () {
                              setState(() {
                                showPassword = !showPassword;
                              });
                            },
                          )
                        : null,
                    hintText: widget.hintText ?? "",
                    hintStyle: AppTypography.of(context).inputHint,
                    border: InputBorder.none,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}
