import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/controllers/surahs_controller.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../quran_view/index_page.dart';
import 'custom_text.dart';
import 'package:quran/quran.dart' as quran;

class CustomPartsDropdown extends StatefulWidget {
  final Map<String, dynamic> part;
  final bool isOpen;
  final VoidCallback onToggle;
  final Future<List<Surah>> Function(int partId)? loadSurahsByPart;

  const CustomPartsDropdown({
    super.key,
    required this.part,
    required this.isOpen,
    required this.onToggle,
    this.loadSurahsByPart,
  });

  @override
  State<CustomPartsDropdown> createState() => _CustomPartsDropdownState();
}

class _CustomPartsDropdownState extends State<CustomPartsDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _showOverlay(
      EvaluationsProvider evaluationsProvider,
      UsersProvider usersProvider) {
    if (_overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final partId = widget.part['id'] as int;
    final screenHeight = MediaQuery.of(context).size.height;
    const double maxDropdownHeight = 200.0;

    double dropdownTop = offset.dy + size.height + 4;

    // If it would go off-screen at the bottom, clamp it to the bottom of the screen
    dropdownTop = dropdownTop.clamp(0, screenHeight - maxDropdownHeight - 10);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Tap outside to close
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          // Dropdown list
          Positioned(
            top: dropdownTop,
            left: offset.dx,
            width: size.width,
            child: Material(
              borderRadius: BorderRadius.circular(8),
              elevation: 6,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: FutureBuilder<List<Surah>>(
                  future: widget.loadSurahsByPart?.call(partId) ??
                      SurahsController().loadSurahsByJuz(partId),
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
                              'custom_part_loading'.tr,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _PartsOverlayState(
                        message: 'custom_part_error'.tr,
                        actionLabel: 'welcome_chart_retry'.tr,
                        onAction: () {
                          _removeOverlay();
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _showOverlay(evaluationsProvider, usersProvider),
                          );
                        },
                      );
                    }

                    final surahs = snapshot.data ?? const <Surah>[];
                    if (surahs.isEmpty) {
                      return _PartsOverlayState(
                        message: 'custom_part_empty'.tr,
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: surahs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Colors.grey),
                      itemBuilder: (context, index) {
                        final surah = surahs[index];
                        return InkWell(
                          onTap: () {
                            Get.toNamed(
                              IndexPage.routeName,
                              parameters: IndexPage.routeParameters(
                                surah: surah,
                                filterTypeId: FilterTypes.parts,
                                juz: widget.part['id'] as int,
                              ),
                            )?.then((_) {
                              evaluationsProvider.getQuranChartData(
                                  usersProvider.selectedUser!.id);
                            });
                            _removeOverlay();
                            widget.onToggle();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                quran.getSurahNameArabic(surah.id),
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black87),
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
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      _controller.reset();
    }
  }

  @override
  void didUpdateWidget(covariant CustomPartsDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    EvaluationsProvider evaluationsProvider =
        Provider.of<EvaluationsProvider>(context, listen: false);
    UsersProvider usersProvider = Provider.of<UsersProvider>(context, listen: false);

    // Avoid triggering overlay changes during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.isOpen && _overlayEntry == null) {
        _showOverlay(evaluationsProvider, usersProvider);
      } else if (!widget.isOpen && _overlayEntry != null) {
        _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.getProportionalWidth(12),
            vertical: SizeConfig.getProportionalHeight(4),
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
          child: Center(
            child: CustomText(
              text: widget.part['name'],
              fontSize: 14,
              color: Colors.white,
              withBackground: false,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _PartsOverlayState extends StatelessWidget {
  const _PartsOverlayState({
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
