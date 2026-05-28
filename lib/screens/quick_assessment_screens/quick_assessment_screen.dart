import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sahifaty/models/ayat.dart';
import 'package:sahifaty/models/evaluation.dart';
import 'package:sahifaty/models/quick_assessment_config.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/services/evaluations_services.dart';
import 'package:sahifaty/services/sahifaty_api.dart';
import 'package:sahifaty/core/utils/surah_localization.dart';
import 'dart:convert';
import 'quiz_screen.dart';
import 'results_screen.dart';

class QuickAssessmentScreen extends StatefulWidget {
  const QuickAssessmentScreen({super.key});

  @override
  State<QuickAssessmentScreen> createState() => _QuickAssessmentScreenState();
}

class _QuickAssessmentScreenState extends State<QuickAssessmentScreen> {
  late List<Ayat> quizAyahs = [];
  late List<String> quizLevelTitles = [];
  late Map<int, int> assessments = {}; // ayahId -> evaluationId
  int currentIndex = 0;
  bool isLoading = true;
  String? errorMessage;
  QuickAssessmentConfig? config;
  final Map<String, List<Evaluation>> _evaluationsByType = {};

  int _compareEvaluationOrder(
    String evaluationType,
    Evaluation first,
    Evaluation second,
  ) {
    int rank(Evaluation evaluation) {
      final code = evaluation.code.trim().toUpperCase();
      if (evaluationType == 'comprehension') {
        const comprehensionOrder = <String, int>{
          '1': 0,
          'YES': 0,
          '0': 1,
          'NO': 1,
        };
        return comprehensionOrder[code] ?? 999;
      }

      const memorizationOrder = <String, int>{
        '3': 0,
        '2': 1,
        '1.01': 2,
        '-1': 3,
      };
      return memorizationOrder[code] ?? 999;
    }

    final rankDiff = rank(first) - rank(second);
    if (rankDiff != 0) {
      return rankDiff;
    }
    return (first.id ?? 0).compareTo(second.id ?? 0);
  }

  Future<List<Evaluation>> _loadCanonicalEvaluations(String evaluationType) async {
    final evaluationsService = EvaluationsServices();
    final fetched = await evaluationsService.getAllEvaluations(type: evaluationType);

    final filtered = fetched.where((evaluation) {
      final code = evaluation.code.trim();
      return evaluation.id != 0 && code != '!';
    }).toList();

    filtered.sort(
      (first, second) => _compareEvaluationOrder(evaluationType, first, second),
    );
    return filtered;
  }

  double _fallbackCardWeight(ContentItem item) {
    switch (item.type) {
      case 'surah':
        if (item.surahId != null) {
          return canonicalAyahCountForSurah(item.surahId!).toDouble();
        }
        return 1.0;
      case 'ayatRange':
        if (item.startAyah != null && item.endAyah != null) {
          return (item.endAyah! - item.startAyah! + 1).toDouble();
        }
        return 1.0;
      case 'juz':
        return 342.0;
      case 'hizb':
        return 86.0;
      case 'hizbQuarter':
        return 21.0;
      default:
        return 1.0;
    }
  }

  List<Map<String, dynamic>> _normalizeAyatPayload(dynamic response) {
    if (response is http.Response) {
      if (response.body.isEmpty) {
        return const [];
      }
      return _normalizeAyatPayload(jsonDecode(response.body));
    }

    final rawList = <dynamic>[];
    if (response is List) {
      rawList.addAll(response);
    } else if (response is Map && response['data'] is List) {
      rawList.addAll(response['data'] as List);
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _toArabicIndicDigits(int value) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((digit) => digits[int.tryParse(digit) ?? 0])
        .join();
  }

  String _buildCardDisplayText({
    required List<Map<String, dynamic>> ayatPayload,
    required String title,
  }) {
    final verses = <String>[];

    for (var i = 0; i < ayatPayload.length; i++) {
      final ayah = ayatPayload[i];
      final text = (ayah['text'] ?? '').toString().trim();
      if (text.isEmpty) {
        continue;
      }

      final ayahNoRaw = ayah['ayahNo'];
      final ayahNo = ayahNoRaw is int
          ? ayahNoRaw
          : int.tryParse(ayahNoRaw?.toString() ?? '');
      final ayahMarker = ayahNo != null && ayahNo > 0
          ? ' (${_toArabicIndicDigits(ayahNo)})'
          : '';
      final suffix = i == ayatPayload.length - 1 && title.isNotEmpty
          ? '$ayahMarker "$title"'
          : ayahMarker;
      verses.add('$text$suffix'.replaceAll('\n', ' ').trim());
    }

    if (verses.isEmpty) {
      return title;
    }

    return verses.join(' ');
  }

  @override
  void initState() {
    super.initState();
    _loadQuizAyahs();
  }

  Future<void> _loadQuizAyahs() async {
    try {
      final sahifatyApi = SahifatyApi();
      
      // Get config from API
      final configResponse = await sahifatyApi.get('quick-assessment-config/active');
      
      if (configResponse.statusCode == 200) {
        final responseData = jsonDecode(configResponse.body);
        // API returns data directly, not wrapped in 'data' field
        if (responseData == null || responseData is! Map) {
          throw Exception('لا يوجد تكوين نشط للتقييم السريع');
        }
        
        config = QuickAssessmentConfig.fromJson(responseData as Map<String, dynamic>);
      } else {
        throw Exception('فشل في جلب إعدادات التقييم السريع');
      }

      // Check if we have levels configured
      if (config!.levels == null || config!.levels!.isEmpty) {
        throw Exception('لا توجد مستويات مكونة للتقييم السريع');
      }
      
      final usedEvaluationTypes = <String>{};
      for (final level in config!.levels!) {
        final levelType = level.evaluationType ?? 'memorization';
        usedEvaluationTypes.add(levelType);
      }

      for (final evaluationType in usedEvaluationTypes) {
        final loaded = await _loadCanonicalEvaluations(evaluationType);
        if (loaded.isEmpty) {
          throw Exception('لا توجد تقييمات فعلية متاحة لهذا النوع في جدول التقييمات: $evaluationType');
        }
        _evaluationsByType[evaluationType] = loaded;
      }

      final allContentItems = <Map<String, dynamic>>[];
      for (final level in config!.levels!) {
        final levelType = level.evaluationType ?? 'memorization';
        for (final item in level.content) {
          allContentItems.add({
            'item': item,
            'evaluationType': levelType,
            'levelTitle': level.getNameAr(),
          });
        }
      }
      
      if (allContentItems.isEmpty) {
        throw Exception('لا توجد عناصر للتقييم');
      }
      
      // Load content items as quiz cards
      // Each content item becomes a single card showing its name/title
      List<Ayat> ayahs = [];
      List<String> levelTitles = [];
      final List<Future<void>> textFetchTasks = [];
      
      for (int i = 0; i < allContentItems.length; i++) {
        final item = allContentItems[i]['item'] as ContentItem;
        final evaluationType = allContentItems[i]['evaluationType'] as String;
        final levelTitle = (allContentItems[i]['levelTitle'] as String?) ?? '';
        String title = '';
        int surahIdForCard = 1;
        int juzForCard = 1;
        final fallbackWeight = _fallbackCardWeight(item);
        double weight = fallbackWeight;
        final showAyahText = item.showAyahText;
        
        // Get title from customLabel or generate it
        if (item.customLabel != null && item.customLabel!['ar'] != null && item.customLabel!['ar']!.isNotEmpty) {
          title = item.customLabel!['ar']!;
          surahIdForCard = item.surahId ?? 1;
          juzForCard = item.juz ?? 1;
        } else {
          // Generate title based on type
          switch (item.type) {
            case 'surah':
              if (item.surahId != null) {
                title = localizedSurahNameById(item.surahId!);
                surahIdForCard = item.surahId!;
              }
              break;
            case 'ayatRange':
              if (item.surahId != null) {
                title = '${localizedSurahNameById(item.surahId!)} (${item.startAyah}-${item.endAyah})';
                surahIdForCard = item.surahId!;
              }
              break;
            case 'juz':
              title = 'الجزء ${item.juz}';
              juzForCard = item.juz ?? 1;
              break;
            case 'hizb':
              title = 'الحزب ${item.hizb}';
              break;
            case 'hizbQuarter':
              title = 'ربع الحزب ${item.hizbQuarter}';
              break;
          }
        }
        
        // Create a simple placeholder Ayat with the title
        // No need to fetch actual ayahs - just create a card with the title
        final cardId = i + 1000;
        final cardAyat = Ayat(
          id: cardId,
          text: title,
          ayahNo: 1,
          juz: juzForCard,
          hizb: 1,
          page: 1,
          weight: weight, // Store weight in ayat
          showAyahText: showAyahText,
          evaluationType: evaluationType,
          surah: Surah(
            id: surahIdForCard,
            nameAr: title,
            ayahCount: 1,
          ),
        );
        
        ayahs.add(cardAyat);
        levelTitles.add(levelTitle);

        textFetchTasks.add(() async {
          try {
            final response = await sahifatyApi.post(
              url: 'ayat/by-level-content',
              body: {
                'content': [item.toJson()],
              },
            );

            final ayatPayload = _normalizeAyatPayload(response);
            if (ayatPayload.isEmpty) {
              return;
            }

            final resolvedWeight = ayatPayload.fold<double>(
              0,
              (sum, ayah) => sum + _asDouble(ayah['weight']),
            );
            if (resolvedWeight > 0) {
              cardAyat.weight = resolvedWeight;
            } else {
              cardAyat.weight = fallbackWeight;
            }

            if (!showAyahText) {
              return;
            }

            final formattedText = _buildCardDisplayText(
              ayatPayload: ayatPayload,
              title: title,
            );
            if (formattedText.trim().isNotEmpty) {
              cardAyat.text = formattedText;
            }
          } catch (_) {
            cardAyat.weight = fallbackWeight;
          }
        }());
      }

      if (textFetchTasks.isNotEmpty) {
        await Future.wait(textFetchTasks);
      }
      
      if (mounted) {
        setState(() {
          quizAyahs = ayahs;
          quizLevelTitles = levelTitles;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  List<Evaluation> _evaluationsForAyah(Ayat ayah) {
    final evaluationType = ayah.evaluationType ?? 'memorization';
    return _evaluationsByType[evaluationType] ?? const [];
  }

  List<Evaluation> _allEvaluations() {
    final deduped = <int, Evaluation>{};
    for (final evaluations in _evaluationsByType.values) {
      for (final evaluation in evaluations) {
        final id = evaluation.id;
        if (id != null) {
          deduped[id] = evaluation;
        }
      }
    }
    return deduped.values.toList(growable: false);
  }

  void _recordAssessment(int evaluationId) {
    final currentAyah = quizAyahs[currentIndex];
    assessments[currentAyah.id!] = evaluationId;

    if (currentIndex < quizAyahs.length - 1) {
      setState(() => currentIndex++);
    } else {
      _submitAssessments();
    }
  }

  void _skipCurrent() {
    if (currentIndex < quizAyahs.length - 1) {
      setState(() => currentIndex++);
      return;
    }
    _submitAssessments();
  }

  void _goToPrevious() {
    if (currentIndex == 0) {
      return;
    }
    setState(() => currentIndex--);
  }

  Future<void> _submitAssessments() async {
    // Navigate to results without submitting (guest mode - no user logged in)
    if (mounted) {
      Get.to(
        ResultsScreen(
          totalAyahs: quizAyahs.length,
          assessments: assessments,
          ayahs: quizAyahs,
          isGuestMode: true, // New parameter to indicate guest mode
          evaluations: _allEvaluations(),
        ),
        transition: Transition.fadeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Get.back(),
                child: const Text('العودة'),
              ),
            ],
          ),
        ),
      );
    }

    if (quizAyahs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('لا توجد آيات')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('العودة'),
          ),
        ),
      );
    }

    return QuizScreen(
      ayah: quizAyahs[currentIndex],
      currentIndex: currentIndex,
      totalAyahs: quizAyahs.length,
      onRatingSelected: _recordAssessment,
      onSkip: _skipCurrent,
      onBack: _goToPrevious,
      customTitle: currentIndex < quizLevelTitles.length ? quizLevelTitles[currentIndex] : null,
      evaluations: _evaluationsForAyah(quizAyahs[currentIndex]),
    );
  }
}
