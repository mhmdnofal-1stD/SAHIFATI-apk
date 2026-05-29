import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../widgets/soft_pattern_background.dart';

import '../../core/constants/colors.dart';
import '../../core/typography/app_typography.dart';
import '../../models/card_model.dart';
import '../../providers/cards_provider.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/global_drawer.dart';
import 'card_detail_screen.dart';

class CardsListScreen extends StatefulWidget {
  static const String routeName = '/cards';

  const CardsListScreen({super.key});

  @override
  State<CardsListScreen> createState() => _CardsListScreenState();
}

class _CardsListScreenState extends State<CardsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CardsProvider>().loadCards(reset: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<CardsProvider>().loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole =
        context.watch<UsersProvider>().activeAccountUser?.userRoleId ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.panelColor,
        elevation: 0,
        leading: const CustomBackButton(),
        title: Text(
          _titleForRole(userRole),
          style: AppTypography.of(context).sectionTitle,
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                if ((Get.locale?.languageCode ?? 'ar') == 'ar') {
                  Scaffold.of(ctx).openDrawer();
                } else {
                  Scaffold.of(ctx).openEndDrawer();
                }
              },
            ),
          ),
        ],
      ),
      drawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
          ? const GlobalDrawer()
          : null,
      endDrawer: (Get.locale?.languageCode ?? 'ar') == 'ar'
          ? null
          : const GlobalDrawer(),
      body: SoftPatternBackground(
        child: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'cards_search_hint'.tr,
                hintStyle: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.mutedText,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          context.read<CardsProvider>().setSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.panelColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.defaultBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.defaultBorderColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: (v) =>
                  context.read<CardsProvider>().setSearch(v.trim()),
            ),
          ),

          // ── Status filter chips (for special roles) ───────────────────
          if (userRole >= 2) _StatusFilterRow(userRole: userRole),

          // ── List ─────────────────────────────────────────────────────
          Expanded(
            child: Consumer<CardsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.cards.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.hasError && provider.cards.isEmpty) {
                  final message = provider.errorMessage
                      .replaceFirst('Exception: ', '')
                      .trim();
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.errorColor,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message.isEmpty ? 'cards_load_error'.tr : message,
                          textAlign: TextAlign.center,
                          style: AppTypography.of(context).bodyDefault,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => provider.loadCards(reset: true),
                          child: Text('cards_retry'.tr),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.cards.isEmpty) {
                  return Center(
                    child: Text(
                      'cards_empty'.tr,
                      style: AppTypography.of(context).bodyDefault.copyWith(
                            color: AppColors.mutedText,
                          ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadCards(reset: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: provider.cards.length +
                        (provider.currentPage < provider.totalPages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.cards.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _CardListTile(card: provider.cards[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _titleForRole(int role) {
    switch (role) {
      case 3:
        return 'cards_my_research'.tr;
      case 4:
        return 'cards_review_queue'.tr;
      case 5:
        return 'cards_accept_queue'.tr;
      default:
        return 'cards_scientific'.tr;
    }
  }
}

// ─── Status filter row ────────────────────────────────────────────────────────

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.userRole});
  final int userRole;

  static const Map<String, String> _allStatuses = {
    '': 'الكل',
    'للمراجعة': 'للمراجعة',
    'قبول جزئي': 'قبول جزئي',
    'قبول أولي': 'قبول أولي',
    'مقبولة': 'مقبولة',
    'مرفوضة': 'مرفوضة',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardsProvider>();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _allStatuses.entries.map((entry) {
          final isSelected = provider.statusFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? AppColors.whiteFontColor
                      : AppColors.blackFontColor,
                ),
              ),
              selected: isSelected,
              onSelected: (_) =>
                  context.read<CardsProvider>().setStatusFilter(entry.key),
              selectedColor: AppColors.brandAccent,
              backgroundColor: AppColors.panelColor,
              checkmarkColor: AppColors.whiteFontColor,
              side: BorderSide(
                color: isSelected
                    ? AppColors.brandAccent
                    : AppColors.defaultBorderColor,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── List tile ────────────────────────────────────────────────────────────────

class _CardListTile extends StatelessWidget {
  const _CardListTile({required this.card});
  final CardModel card;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.panelColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lineColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Get.toNamed(
          CardDetailScreen.routeName,
          parameters: {'id': card.id.toString()},
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status dot
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 10),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor(card.status),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      card.subjectDisplayName,
                      style: AppTypography.of(context).sectionTitle.copyWith(
                            fontSize: 14,
                          ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.contentLabel,
                      style: AppTypography.of(context).bodyDefault.copyWith(
                            color: AppColors.mutedText,
                            fontSize: 13,
                          ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _StatusBadge(status: card.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'مقبولة':
        bg = AppColors.mintSurface;
        fg = AppColors.successColor;
        break;
      case 'مرفوضة':
        bg = const Color(0xFFFFE5E5);
        fg = AppColors.errorColor;
        break;
      case 'قبول أولي':
        bg = const Color(0xFFE9F5E0);
        fg = AppColors.easyColor;
        break;
      case 'قبول جزئي':
        bg = const Color(0xFFE8EEF9);
        fg = AppColors.revisionColor;
        break;
      default:
        bg = AppColors.warmSurface;
        fg = AppColors.mutedText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
