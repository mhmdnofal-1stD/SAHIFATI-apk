import 'package:flutter/material.dart';
import 'package:sahifaty/core/constants/fonts.dart';
import '../../../core/constants/colors.dart';

class CustomAuthenticationTextField extends StatefulWidget {
  const CustomAuthenticationTextField({
    super.key,
    this.hintText,
    required this.obscureText,
    required this.textEditingController,
    required this.borderColor,
    this.borderWidth,
    this.isSettings,
  });

  final String? hintText;
  final bool obscureText;
  final TextEditingController textEditingController;
  final Color borderColor;
  final double? borderWidth;
  final bool? isSettings;

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
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              width: widget.borderWidth ?? 1.0, color: widget.borderColor),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
                textAlign: TextAlign.left,
                controller: widget.textEditingController,
                obscureText: widget.obscureText && !showPassword,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  suffixIcon: widget.obscureText
                      ? IconButton(
                          icon: !showPassword
                              ? const Icon(Icons.visibility)
                              : const Icon(Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                        )
                      : null,
                  hintText: widget.hintText ?? "",
                  hintStyle: TextStyle(
                    color: AppColors.hintTextColor,
                    fontFamily: AppFonts.primaryFont,
                  ),
                  border: InputBorder.none,
                )),
          ),
        ),
      ),
    );
  }
}
