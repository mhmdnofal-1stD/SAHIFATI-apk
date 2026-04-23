import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/constants/colors.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/sahifa_screen/sahifa_screen.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/global_drawer.dart';
import '../widgets/no_pop_scope.dart';
import '../widgets/responsive_content_shell.dart';

class QuestionsCompletionScreen extends StatefulWidget {
  const QuestionsCompletionScreen({
    super.key,
    required this.skipped,
    required this.totalLevels,
    required this.completedLevels,
    required this.totalItems,
    required this.completedItems,
    required this.lastReachedLevel,
  });

  final bool skipped;
  final int totalLevels;
  final int completedLevels;
  final int totalItems;
  final int completedItems;
  final int lastReachedLevel;

  @override
  State<QuestionsCompletionScreen> createState() =>
      _QuestionsCompletionScreenState();
}

class _QuestionsCompletionScreenState extends State<QuestionsCompletionScreen> {
  bool _isOpeningSahifa = false;
  String? _errorMessage;

  String text(String arabic, String english) {
    return (Get.locale?.languageCode ?? 'ar') == 'ar' ? arabic : english;
  }

  Future<void> _openSahifa() async {
    final usersProvider = context.read<UsersProvider>();
    final evaluationsProvider = context.read<EvaluationsProvider>();
    final user = usersProvider.selectedUser;

    setState(() {
      _isOpeningSahifa = true;
      _errorMessage = null;
    });

    try {
      if (user != null) {
        await evaluationsProvider.getQuranChartData(user.id);
      }

      if (!mounted) {
        return;
      }

      Get.off(() => const SahifaScreen(firstScreen: false));
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _errorMessage = message.isEmpty
            ? text(
                'تعذر فتح الصحيفة الآن. حاول مرة أخرى بعد لحظة.',
                'We could not open the Sahifa right now. Please try again in a moment.',
              )
            : message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningSahifa = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final completionRatio = widget.totalItems == 0
        ? 0.0
        : widget.completedItems / widget.totalItems;
    final remainingItems = widget.totalItems - widget.completedItems;

    return NoPopScope(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: Text(
                text('ملخص التقييم', 'Assessment summary'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackFontColor,
                ),
              ),
              leading: const CustomBackButton(),
              actions: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      if ((Get.locale?.languageCode ?? 'ar') == 'ar') {
                        Scaffold.of(context).openDrawer();
                      } else {
                        Scaffold.of(context).openEndDrawer();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        drawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
            ? const GlobalDrawer()
            : null,
        endDrawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
            ? null
            : const GlobalDrawer(),
        body: ResponsiveContentShell(
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF4EFE6), Color(0xFFE7F0E8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFD9DED7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.skipped
                                ? text('أنهيت الجولة الحالية مبكرًا', 'You ended this round early')
                                : text('اكتمل تقييم البداية', 'The kickoff assessment is complete'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.buttonColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.skipped
                                ? text(
                                    'هذا الملخص يعرض وضعك الحالي بصدق قبل الانتقال إلى الصحيفة. يمكنك العودة للأسئلة لاحقًا لإكمال الوحدات المتبقية.',
                                    'This summary shows your current state honestly before you continue to the Sahifa. You can come back later to finish the remaining units.',
                                  )
                                : text(
                                    'أنهيت جولة التقييم الافتتاحية. قبل الانتقال إلى الصحيفة، هذه قراءة سريعة لما تم تغطيته وما بقي بدون افتراضات مضللة.',
                                    'You completed the opening assessment round. Before entering the Sahifa, here is a quick view of what was covered and what still remains, without misleading assumptions.',
                                  ),
                            style: const TextStyle(
                              fontSize: 26,
                              height: 1.35,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: completionRatio.clamp(0, 1),
                              minHeight: 9,
                              backgroundColor: Colors.white,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.buttonColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _SummaryMetricCard(
                          label: text('الوحدات المكتملة', 'Completed units'),
                          value: '${widget.completedItems} / ${widget.totalItems}',
                        ),
                        _SummaryMetricCard(
                          label: text('المستويات المكتملة', 'Completed levels'),
                          value: '${widget.completedLevels} / ${widget.totalLevels}',
                        ),
                        _SummaryMetricCard(
                          label: text('آخر مستوى وصلت إليه', 'Last level reached'),
                          value: '${widget.lastReachedLevel} / ${widget.totalLevels}',
                        ),
                        _SummaryMetricCard(
                          label: text('الوحدات المتبقية', 'Remaining units'),
                          value: '$remainingItems',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFDDE3DA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text('ماذا يعني هذا؟', 'What does this mean?'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.skipped
                                ? text(
                                    'الصحيفة ستفتح بناءً على ما تم تقييمه فعلاً فقط. الوحدات غير المكتملة ستبقى خارج التقدم حتى تعود إليها لاحقًا.',
                                    'The Sahifa will open based only on what was actually assessed. Incomplete units remain outside your progress until you come back to them later.',
                                  )
                                : text(
                                    'الصحيفة التالية ستعتمد على هذا التقييم الافتتاحي وما كان لديك أصلًا من بيانات تقييم حقيقية. إذا كانت هناك وحدات متبقية فهي ما تزال تحتاج تقييمًا لاحقًا.',
                                    'The next Sahifa view will rely on this kickoff assessment plus any real evaluation data you already had. If some units remain, they still need assessment later.',
                                  ),
                            style: const TextStyle(height: 1.6),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.errorColor,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _isOpeningSahifa ? null : _openSahifa,
                                icon: _isOpeningSahifa
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.auto_graph),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.buttonColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                ),
                                label: Text(
                                  _isOpeningSahifa
                                      ? text('جاري فتح الصحيفة...', 'Opening the Sahifa...')
                                      : text('متابعة إلى الصحيفة', 'Continue to the Sahifa'),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isOpeningSahifa
                                    ? null
                                    : () => Get.back<void>(),
                                icon: const Icon(Icons.arrow_back),
                                label: Text(
                                  text('العودة إلى الأسئلة', 'Back to the questions'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE3DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF59625D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}