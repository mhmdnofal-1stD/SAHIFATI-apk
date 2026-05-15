import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../providers/evaluations_provider.dart';

class PendingSyncBanner extends StatelessWidget {
  const PendingSyncBanner({super.key, this.bottomPadding = 16});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Selector<EvaluationsProvider, int>(
      selector: (_, provider) => provider.pendingSyncCount,
      builder: (context, pendingSyncCount, _) {
        if (pendingSyncCount <= 0) {
          return const SizedBox.shrink();
        }

        final label = pendingSyncCount > 99 ? '99+' : pendingSyncCount.toString();

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Tooltip(
              message: 'pending_sync_title'.tr,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2BE66), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      color: Color(0xFF8A5A00),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A5A00),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}