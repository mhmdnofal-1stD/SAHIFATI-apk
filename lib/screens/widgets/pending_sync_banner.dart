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

        final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
        final title = isArabic
            ? 'تقييمات محفوظة بانتظار المزامنة'
            : 'Saved assessments are waiting to sync';
        final subtitle = isArabic
            ? pendingSyncCount == 1
                ? 'يوجد تقييم واحد محفوظ على هذا الجهاز وسيُرسل تلقائيًا عند عودة الاتصال.'
                : 'يوجد $pendingSyncCount تقييمات محفوظة على هذا الجهاز وسيتم إرسالها تلقائيًا عند عودة الاتصال.'
            : pendingSyncCount == 1
                ? 'One assessment is saved on this device and will be sent automatically when the connection returns.'
                : '$pendingSyncCount assessments are saved on this device and will be sent automatically when the connection returns.';

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4DB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2BE66)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE7AE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.sync_problem_rounded,
                      color: Color(0xFF8A5A00),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5D3A00),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF6B4C16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A5A00),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      pendingSyncCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}