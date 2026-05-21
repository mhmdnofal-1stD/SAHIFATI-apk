import 'package:flutter/material.dart';

String supervisionEvaluationDisplayName(Map<String, dynamic> evaluation) {
  final rawName = evaluation['name'];
  if (rawName is Map) {
    final arabic = rawName['ar']?.toString().trim();
    if (arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
    final english = rawName['en']?.toString().trim();
    if (english != null && english.isNotEmpty) {
      return english;
    }
  }

  final nameAr = evaluation['nameAr']?.toString().trim();
  if (nameAr != null && nameAr.isNotEmpty) {
    return nameAr;
  }

  return '';
}

bool supervisionIsProficientEvaluation(Map<String, dynamic> evaluation) {
  final code = (evaluation['code']?.toString() ?? '').trim().toLowerCase();
  if (code == 'g' ||
      code.startsWith('mtkn') ||
      code == 'mastered' ||
      code == 'proficient') {
    return true;
  }

  final name = supervisionEvaluationDisplayName(evaluation).toLowerCase();
  return name.contains('متمكن') ||
      name.contains('متقن') ||
      name.contains('mastered') ||
      name.contains('proficient');
}

bool supervisionIsReviewEvaluation(Map<String, dynamic> evaluation) {
  final code = (evaluation['code']?.toString() ?? '').trim().toLowerCase();
  if (code == 's' || code.startsWith('mraj') || code == 'review') {
    return true;
  }

  final name = supervisionEvaluationDisplayName(evaluation).toLowerCase();
  return name.contains('مراجعة') || name.contains('review');
}

bool supervisionIsEasyEvaluation(Map<String, dynamic> evaluation) {
  final code = (evaluation['code']?.toString() ?? '').trim().toLowerCase();
  if (code == 'easy' || code == 'gid' || code == 'good') {
    return true;
  }

  final name = supervisionEvaluationDisplayName(evaluation).toLowerCase();
  return name.contains('سهل') ||
      name.contains('جيد') ||
      name.contains('easy') ||
      name.contains('good');
}

bool supervisionIsDifficultEvaluation(Map<String, dynamic> evaluation) {
  final code = (evaluation['code']?.toString() ?? '').trim().toLowerCase();
  if (code == 'hard' ||
      code == 'difficult' ||
      code == 'weak' ||
      code.startsWith('daeif')) {
    return true;
  }

  final name = supervisionEvaluationDisplayName(evaluation).toLowerCase();
  return name.contains('صعب') ||
      name.contains('ضعيف') ||
      name.contains('hard') ||
      name.contains('difficult') ||
      name.contains('weak');
}

int supervisionEvaluationPriority(Map<String, dynamic> evaluation) {
  if (supervisionIsProficientEvaluation(evaluation)) {
    return 0;
  }
  if (supervisionIsReviewEvaluation(evaluation)) {
    return 1;
  }
  if (supervisionIsEasyEvaluation(evaluation)) {
    return 2;
  }
  if (supervisionIsDifficultEvaluation(evaluation)) {
    return 3;
  }
  return 10;
}

Color supervisionResolveEvaluationColor(Map<String, dynamic> evaluation) {
  final rawColor = evaluation['color']?.toString().trim();
  final parsedColor = _tryParseHexColor(rawColor);
  if (parsedColor != null) {
    return parsedColor;
  }
  if (supervisionIsProficientEvaluation(evaluation)) {
    return const Color(0xFF4FD99A);
  }
  if (supervisionIsReviewEvaluation(evaluation)) {
    return const Color(0xFF6EC5FF);
  }
  if (supervisionIsEasyEvaluation(evaluation)) {
    return const Color(0xFFFFB256);
  }
  if (supervisionIsDifficultEvaluation(evaluation)) {
    return const Color(0xFFFF6E73);
  }
  return const Color(0xFF94A3B8);
}

/// Maps an evaluation to a numeric score used by [SurahVerseChart].
///
/// Returns 3 / 2 / 1 / 0 / -1 matching the chart's height scale.
double supervisionEvaluationScore(Map<String, dynamic> evaluation) {
  if (supervisionIsProficientEvaluation(evaluation)) return 3.0;
  if (supervisionIsReviewEvaluation(evaluation)) return 2.0;
  if (supervisionIsEasyEvaluation(evaluation)) return 1.0;
  if (supervisionIsDifficultEvaluation(evaluation)) return -1.0;
  return 0.0;
}

String supervisionFormatPercent(
  num value, {
  int fractionDigits = 1,
}) {
  final formatted = value.toStringAsFixed(fractionDigits);
  if (!formatted.contains('.')) {
    return formatted;
  }
  return formatted
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

Color? _tryParseHexColor(String? rawColor) {
  if (rawColor == null || rawColor.isEmpty) {
    return null;
  }

  final normalized = rawColor.replaceAll('#', '').trim();
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  if (hex.length != 8) {
    return null;
  }

  final value = int.tryParse(hex, radix: 16);
  if (value == null) {
    return null;
  }

  return Color(value);
}