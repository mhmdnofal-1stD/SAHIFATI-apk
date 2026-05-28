import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:sahifaty/core/constants/assets.dart';

import 'auth_social_section.dart';

class HuaweiWebAuthButton extends StatefulWidget {
  const HuaweiWebAuthButton({
    super.key,
    required this.onStart,
    required this.onError,
    required this.isBusy,
  });

  final Future<void> Function() onStart;
  final void Function(Object error) onError;
  final bool isBusy;

  @override
  State<HuaweiWebAuthButton> createState() => _HuaweiWebAuthButtonState();
}

class _HuaweiWebAuthButtonState extends State<HuaweiWebAuthButton> {
  bool _isSubmitting = false;

  Future<void> _startHuaweiSignIn() async {
    if (_isSubmitting || widget.isBusy) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.onStart();
    } catch (error) {
      widget.onError(error);
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting || widget.isBusy) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    return AuthCompactSocialButton(
      semanticLabel: 'social_provider_huawei'.tr,
      onPressed: _startHuaweiSignIn,
      isBusy: false,
      icon: SvgPicture.asset(Assets.huaweiIcon, width: 24, height: 24),
    );
  }
}