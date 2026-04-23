import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/controllers/general_controller.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/providers/surahs_provider.dart';
import 'package:sahifaty/screens/quran_view/index_page.dart';
import '../../controllers/surahs_controller.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../../providers/evaluations_provider.dart';
import '../../providers/users_provider.dart';
import 'custom_text.dart';
import 'package:quran/quran.dart' as quran;

class CustomThirdsDropdown extends StatefulWidget {
  const CustomThirdsDropdown({
    super.key,
    required this.third,
    required this.isOpen,
    required this.onToggle,
  });

  final int third;
  final bool isOpen;
  final VoidCallback onToggle;

  @override
  State<CustomThirdsDropdown> createState() => _CustomThirdsDropdownState();
}

class _CustomThirdsDropdownState extends State<CustomThirdsDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _sideOverlayEntry;

  late AnimationController _controller;

  List<Map<String, dynamic>> get dropdownOptions => widget.third == 1
      ? GeneralController().firstThird
      : widget.third == 2
          ? GeneralController().secondThird
          : GeneralController().thirdThird;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  void _showOverlay(SurahsProvider surahsProvider, EvaluationsProvider evaluationsProvider, UsersProvider usersProvider) {
    if (_overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final overlayWidth = size.width;
    const overlayHeight = 260.0;

// LEFT (already fixed earlier)
    double calculatedLeft = offset.dx + (_controller.value * 80);
    calculatedLeft = calculatedLeft.clamp(0, screenWidth - overlayWidth);

// TOP (new fix)
    double calculatedTop = offset.dy + size.height + 4;
    calculatedTop = calculatedTop.clamp(0, screenHeight - overlayHeight);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _removeOverlay();
                _controller.reverse();
                widget.onToggle();
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            top: calculatedTop,
            left: calculatedLeft,
            width: overlayWidth,
            child: Material(
              borderRadius: BorderRadius.circular(8),
              elevation: 6,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: dropdownOptions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.grey, height: 1),
                  itemBuilder: (context, index) {
                    final option = dropdownOptions[index];
                    return InkWell(
                      onTap: () async {
                        _showSideOverlay(
                          option['name'],
                          option['id'],
                          index,
                          offset,
                          size,
                          surahsProvider,
                          evaluationsProvider,
                          usersProvider,
                          SurahsController().loadSurahsByJuz(option['id']),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: CustomText(
                            text: option['name'],
                            fontSize: 14,
                            withBackground: false,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward();
  }

  void _showSideOverlay(
    String optionName,
    int juzId,
    int index,
    Offset parentOffset,
    Size buttonSize,
    SurahsProvider surahsProvider,
    EvaluationsProvider evaluationsProvider,
    UsersProvider usersProvider,
    Future<List<Surah>> surahsFuture,
  ) {
    _removeSideOverlay();
    final isArabic = (Get.locale?.languageCode ?? 'ar') == 'ar';
    String text(String arabic, String english) => isArabic ? arabic : english;

    const double itemHeight = 40;
    final double topPosition =
        parentOffset.dy + buttonSize.height + (index * itemHeight);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    const overlayWidth = 160.0;
    const overlayHeight = 200.0;

// LEFT
    double calculatedLeft = parentOffset.dx - 180 + (_controller.value * 100);
    calculatedLeft = calculatedLeft.clamp(0, screenWidth - overlayWidth);
// TOP
    double calculatedTop = topPosition;
    calculatedTop = calculatedTop.clamp(0, screenHeight - overlayHeight);

    _sideOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: calculatedTop,
        left: calculatedLeft,
        width: overlayWidth,
        child: Material(
          borderRadius: BorderRadius.circular(8),
          elevation: 6,
          color: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: FutureBuilder<List<Surah>>(
              future: surahsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          text(
                            'جارٍ تجهيز السور داخل $optionName...',
                            'Preparing the surahs inside $optionName...',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _ThirdsOverlayState(
                    message: text(
                      'تعذر تحميل السور لهذا المسار الآن.',
                      'We could not load the surahs for this path right now.',
                    ),
                    actionLabel: text('إعادة المحاولة', 'Retry'),
                    onAction: () {
                      _removeSideOverlay();
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _showSideOverlay(
                          optionName,
                          juzId,
                          index,
                          parentOffset,
                          buttonSize,
                          surahsProvider,
                          evaluationsProvider,
                          usersProvider,
                          SurahsController().loadSurahsByJuz(juzId),
                        ),
                      );
                    },
                  );
                }

                final surahs = snapshot.data ?? const <Surah>[];
                if (surahs.isEmpty) {
                  return _ThirdsOverlayState(
                    message: text(
                      'لا توجد سور جاهزة لهذا المسار حاليًا.',
                      'No surahs are available for this path right now.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: surahs.length,
                  itemBuilder: (_, i) {
                    final sura = surahs[i];

                    return InkWell(
                      onTap: () {
                        _removeSideOverlay();
                        _removeOverlay();
                        _controller.value = 0.0;
                        Get.to(IndexPage(
                          surah: sura,
                          filterTypeId: FilterTypes.thirds,
                          juz: juzId,
                        ))?.then((_) {
                          evaluationsProvider
                              .getQuranChartData(usersProvider.selectedUser!.id);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: CustomText(
                            text: Get.locale?.languageCode == 'ar'
                                ? quran.getSurahNameArabic(sura.id)
                                : quran.getSurahName(sura.id),
                            fontSize: 13,
                            withBackground: false,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_sideOverlayEntry!);
  }

  void _removeSideOverlay() {
    _sideOverlayEntry?.remove();
    _sideOverlayEntry = null;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    if (mounted && _controller.isAnimating) {
      _controller.value = 0;
    }
  }

  void _toggleAnimation() {
    if (_controller.status == AnimationStatus.completed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(CustomThirdsDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mounted) return;

    final surahsProvider = Provider.of<SurahsProvider>(context, listen: false);
    EvaluationsProvider evaluationsProvider = Provider.of<EvaluationsProvider>(context);
    UsersProvider usersProvider = Provider.of<UsersProvider>(context);
    if (_overlayEntry != null) return;

    if (widget.isOpen) {
      _toggleAnimation();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showOverlay(surahsProvider, evaluationsProvider, usersProvider));
    } else {
      _toggleAnimation();
      _removeOverlay();
      _removeSideOverlay();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(widget.isOpen ? _controller.value * 80 : 0, 0),
          child: CompositedTransformTarget(
            link: _layerLink,
            child: GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.getProportionalWidth(12),
                  vertical: SizeConfig.getProportionalWidth(4),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: Center(
                  child: CustomText(
                    text: widget.third == 1
                        ? "first_third".tr
                        : widget.third == 2
                            ? "second_third".tr
                            : "third_third".tr,
                    fontSize: 14,
                    color: Colors.white,
                    withBackground: false,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThirdsOverlayState extends StatelessWidget {
  const _ThirdsOverlayState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
