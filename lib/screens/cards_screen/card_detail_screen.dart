import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran;
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/fonts.dart';
import '../../core/typography/app_typography.dart';
import '../../models/card_model.dart';
import '../../providers/cards_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';

class CardDetailScreen extends StatefulWidget {
  static const String routeName = '/card-detail';

  const CardDetailScreen({super.key, required this.cardId});

  final int cardId;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _rejectReasonController = TextEditingController();
  bool _isSubmitting = false;
  bool _showRejectForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CardsProvider>().loadCard(widget.cardId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _rejectReasonController.dispose();
    super.dispose();
  }

  // ── Role helpers ─────────────────────────────────────────────────────────────

  int get _userRole =>
      context.read<UsersProvider>().activeAccountUser?.userRoleId ?? 0;

  bool _canChangeStatus(CardModel card) {
    if (_userRole == 2) return true; // admin always
    if (_userRole == 4) {
      // reviewer: can act on pending or partial
      return card.isPending || card.isPartialApproval;
    }
    if (_userRole == 5) {
      // admitter: can act on initial approval
      return card.isInitialApproval;
    }
    return false;
  }

  List<String> _availableNextStatuses(CardModel card) {
    if (_userRole == 4) {
      // Reviewer
      if (card.isPending) {
        return ['قبول جزئي', 'قبول أولي', 'مرفوضة'];
      }
      if (card.isPartialApproval) {
        return ['قبول أولي', 'مرفوضة'];
      }
    }
    if (_userRole == 5) {
      // Admitter
      if (card.isInitialApproval) {
        return ['مقبولة', 'مرفوضة'];
      }
    }
    if (_userRole == 2) {
      return ['للمراجعة', 'قبول جزئي', 'قبول أولي', 'مقبولة', 'مرفوضة'];
    }
    return [];
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _submitStatus(String status) async {
    if (_isSubmitting) return;
    if (status == 'مرفوضة' && !_showRejectForm) {
      setState(() => _showRejectForm = true);
      return;
    }

    setState(() => _isSubmitting = true);
    final comment = _commentController.text.trim();
    final rejectReason = _rejectReasonController.text.trim();

    final ok = await context.read<CardsProvider>().updateStatus(
          widget.cardId,
          status: status,
          comment: comment.isNotEmpty ? comment : null,
          rejectReason: rejectReason.isNotEmpty ? rejectReason : null,
        );

    setState(() {
      _isSubmitting = false;
      _showRejectForm = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم تحديث الحالة' : 'فشل تحديث الحالة'),
        backgroundColor: ok ? AppColors.successColor : AppColors.errorColor,
      ),
    );
  }

  Future<void> _submitComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    final ok = await context.read<CardsProvider>().addComment(
          widget.cardId,
          comment,
        );
    setState(() => _isSubmitting = false);
    if (ok) _commentController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تمت إضافة التعليق' : 'فشل إرسال التعليق'),
        backgroundColor: ok ? AppColors.successColor : AppColors.errorColor,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.panelColor,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          'تفاصيل البطاقة',
          style: AppTypography.of(context).sectionTitle,
        ),
      ),
      body: Consumer<CardsProvider>(
        builder: (context, provider, _) {
          if (provider.isDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final card = provider.selectedCard;
          if (card == null) {
            return Center(
              child: Text(
                'لم يتم تحميل البطاقة',
                style: AppTypography.of(context).bodyDefault,
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InfoCard(card: card),
                const SizedBox(height: 16),
                _ResearchersSection(researchers: card.researchers),
                const SizedBox(height: 16),
                _CommentsSection(comments: card.reviewerComments),
                const SizedBox(height: 16),

                // ── Comment input (roles 3,4,5,2) ──────────────────────────
                if (_userRole >= 3) ...[
                  _CommentInputCard(
                    controller: _commentController,
                    isSubmitting: _isSubmitting,
                    onSend: _submitComment,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Reject reason form ────────────────────────────────────
                if (_showRejectForm) ...[
                  _RejectReasonCard(
                    controller: _rejectReasonController,
                    onCancel: () => setState(() => _showRejectForm = false),
                    onConfirm: () => _submitStatus('مرفوضة'),
                    isSubmitting: _isSubmitting,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Workflow actions ──────────────────────────────────────
                if (_canChangeStatus(card))
                  _WorkflowActions(
                    statuses: _availableNextStatuses(card),
                    isSubmitting: _isSubmitting,
                    onSelect: _submitStatus,
                  ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.card});
  final CardModel card;

  @override
  Widget build(BuildContext context) {
    final ayatValue = _ayatValue();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelColor,
        borderRadius: BorderRadius.circular(12),
        border:
            const Border.fromBorderSide(BorderSide(color: AppColors.lineColor)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Row(label: 'الموضوع', value: card.subjectDisplayName),
          const Divider(height: 20, color: AppColors.lineColor),
          _Row(label: 'النطاق', value: card.contentLabel),
          if (ayatValue.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.lineColor),
            _Row(label: 'الآيات', value: ayatValue, useQuranVerseStyle: true),
          ],
          const Divider(height: 20, color: AppColors.lineColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatusBadgeSmall(status: card.status),
              Text(
                'الحالة',
                style: AppTypography.of(context).bodyDefault.copyWith(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
          if (card.createdAt != null) ...[
            const Divider(height: 20, color: AppColors.lineColor),
            _Row(
              label: 'تاريخ الإنشاء',
              value: _formatDate(card.createdAt!),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  String _ayatValue() {
    final content = card.content;
    final type = (content['type']?.toString() ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]+'), '');
    final surahId = _toInt(content['surahId']);
    if (surahId == null || surahId < 1 || surahId > quran.totalSurahCount) {
      return '';
    }

    if (type == 'ayah') {
      final ayahNo = _toInt(content['ayahNo']);
      return _verseText(surahId, ayahNo);
    }

    if (type == 'ayahrange') {
      final startAyah = _toInt(content['startAyah']);
      final endAyah = _toInt(content['endAyah']);
      if (startAyah == null || endAyah == null) {
        return '';
      }

      final lower = startAyah <= endAyah ? startAyah : endAyah;
      final upper = startAyah <= endAyah ? endAyah : startAyah;
      final verses = <String>[];
      for (var ayahNo = lower; ayahNo <= upper; ayahNo++) {
        final verse = _verseText(surahId, ayahNo);
        if (verse.isNotEmpty) {
          verses.add(verse);
        }
      }
      return verses.join('\n\n');
    }

    return '';
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('${value ?? ''}');
  }

  String _verseText(int surahId, int? ayahNo) {
    if (ayahNo == null || ayahNo <= 0) {
      return '';
    }

    try {
      return quran.getVerse(surahId, ayahNo, verseEndSymbol: false).trim();
    } catch (_) {
      return '';
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.useQuranVerseStyle = false,
  });
  final String label;
  final String value;
  final bool useQuranVerseStyle;

  @override
  Widget build(BuildContext context) {
    final valueStyle = useQuranVerseStyle
        ? AppTypography.of(context).quranVerse.copyWith(
              fontFamily: AppFonts.versesFont,
              fontSize: 24,
              height: 1.9,
              color: AppColors.blackFontColor,
            )
        : AppTypography.of(context).bodyDefault.copyWith(
              fontSize: 14,
            );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            value,
            style: valueStyle,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTypography.of(context).bodyDefault.copyWith(
                color: AppColors.mutedText,
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

class _ResearchersSection extends StatelessWidget {
  const _ResearchersSection({required this.researchers});
  final List<Map<String, dynamic>> researchers;

  @override
  Widget build(BuildContext context) {
    if (researchers.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelColor,
        borderRadius: BorderRadius.circular(12),
        border:
            const Border.fromBorderSide(BorderSide(color: AppColors.lineColor)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'الباحثون',
            style: AppTypography.of(context).sectionTitle.copyWith(
                  fontSize: 13,
                ),
          ),
          const SizedBox(height: 8),
          ...researchers.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${r['username'] ?? ''} — ${r['email'] ?? ''}',
                  style: AppTypography.of(context).bodyDefault.copyWith(
                        fontSize: 13,
                        color: AppColors.mutedText,
                      ),
                  textDirection: TextDirection.rtl,
                ),
              )),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({required this.comments});
  final List<Map<String, dynamic>> comments;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelColor,
        borderRadius: BorderRadius.circular(12),
        border:
            const Border.fromBorderSide(BorderSide(color: AppColors.lineColor)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'تعليقات المراجعة',
            style: AppTypography.of(context).sectionTitle.copyWith(
                  fontSize: 13,
                ),
          ),
          const SizedBox(height: 8),
          ...comments.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warmSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (c['comment'] as String?) ?? '',
                      style: AppTypography.of(context)
                          .bodyDefault
                          .copyWith(fontSize: 13),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (c['user'] is Map
                              ? c['user']['username']?.toString()
                              : null) ??
                          '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _CommentInputCard extends StatelessWidget {
  const _CommentInputCard({
    required this.controller,
    required this.isSubmitting,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelColor,
        borderRadius: BorderRadius.circular(12),
        border:
            const Border.fromBorderSide(BorderSide(color: AppColors.lineColor)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.send, color: AppColors.brandAccent),
                  onPressed: onSend,
                ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'card_comment_hint'.tr,
                hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectReasonCard extends StatelessWidget {
  const _RejectReasonCard({
    required this.controller,
    required this.onCancel,
    required this.onConfirm,
    required this.isSubmitting,
  });

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(12),
        border:
            const Border.fromBorderSide(BorderSide(color: Color(0xFFFFCCCC))),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'card_reject_reason_title'.tr,
            style: AppTypography.of(context).bodyDefault.copyWith(
                  color: AppColors.errorColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            textDirection: TextDirection.rtl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'card_reject_reason_hint'.tr,
              hintStyle:
                  const TextStyle(color: AppColors.mutedText, fontSize: 13),
              filled: true,
              fillColor: AppColors.panelColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.lineColor)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isSubmitting ? null : onCancel,
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isSubmitting ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorColor,
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('تأكيد الرفض',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkflowActions extends StatelessWidget {
  const _WorkflowActions({
    required this.statuses,
    required this.isSubmitting,
    required this.onSelect,
  });

  final List<String> statuses;
  final bool isSubmitting;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: statuses.map((status) {
        final isReject = status == 'مرفوضة';
        final isApprove = status == 'مقبولة' || status == 'قبول أولي';
        return ElevatedButton(
          onPressed: isSubmitting ? null : () => onSelect(status),
          style: ElevatedButton.styleFrom(
            backgroundColor: isReject
                ? AppColors.errorColor
                : isApprove
                    ? AppColors.successColor
                    : AppColors.brandAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusBadgeSmall extends StatelessWidget {
  const _StatusBadgeSmall({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: _fg(status), fontSize: 11),
      ),
    );
  }

  Color _bg(String s) {
    switch (s) {
      case 'مقبولة':
        return AppColors.mintSurface;
      case 'مرفوضة':
        return const Color(0xFFFFE5E5);
      case 'قبول أولي':
        return const Color(0xFFE9F5E0);
      case 'قبول جزئي':
        return const Color(0xFFE8EEF9);
      default:
        return AppColors.warmSurface;
    }
  }

  Color _fg(String s) {
    switch (s) {
      case 'مقبولة':
        return AppColors.successColor;
      case 'مرفوضة':
        return AppColors.errorColor;
      case 'قبول أولي':
        return AppColors.easyColor;
      case 'قبول جزئي':
        return AppColors.revisionColor;
      default:
        return AppColors.mutedText;
    }
  }
}
