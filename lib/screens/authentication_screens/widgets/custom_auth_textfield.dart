import 'package:flutter/material.dart';
import 'package:sahifaty/core/constants/fonts.dart';

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
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              width: widget.borderWidth ?? 1.0, color: widget.borderColor),
          color: const Color(0xFFFCFBF8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 12,
              offset: Offset(0, 6),
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
                            color: const Color(0xFF7B8494),
                            size: 20,
                          ),
                    suffixIcon: widget.obscureText
                        ? IconButton(
                            icon: !showPassword
                                ? const Icon(Icons.visibility, color: Color(0xFF7B8494))
                                : const Icon(Icons.visibility_off, color: Color(0xFF7B8494)),
                            onPressed: () {
                              setState(() {
                                showPassword = !showPassword;
                              });
                            },
                          )
                        : null,
                    hintText: widget.hintText ?? "",
                    hintStyle: TextStyle(
                      color: const Color(0xFF9AA2AE),
                      fontFamily: AppFonts.primaryFont,
                    ),
                    border: InputBorder.none,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}
