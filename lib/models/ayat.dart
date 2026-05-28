import 'package:sahifaty/core/utils/surah_localization.dart';

import 'package:sahifaty/models/school_level.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/models/user_evaluation.dart';

class Ayat {
  int? _id;
  String text;
  String? translationText;
  String? translationLanguage;
  int ayahNo;
  int juz;
  int hizb;
  int? hizbQuarter;
  int? page;
  int? wordCount;
  int? letterCount;
  double? weight;
  bool showAyahText;
  String? ayahType;
  String? evaluationType;
  List<SchoolLevel>? schoolLevels;
  List<String>? subjects;
  Surah surah;
  UserEvaluation? userEvaluation;
  List<TeacherRecommendation> teacherRecommendations;

  Ayat({
    int? id,
    required this.text,
    this.translationText,
    this.translationLanguage,
    required this.ayahNo,
    required this.juz,
    required this.hizb,
    this.hizbQuarter,
    this.page,
    this.wordCount,
    this.letterCount,
    this.weight,
    this.showAyahText = true,
    this.ayahType,
    this.evaluationType,
    this.schoolLevels,
    this.subjects,
    required this.surah,
    this.userEvaluation,
    List<TeacherRecommendation>? teacherRecommendations,
  })  : teacherRecommendations = teacherRecommendations ?? const [],
        _id = id;

  int? get id => _id;

  factory Ayat.fromJson(Map<String, dynamic> json) {
    final surah = Surah.fromJson(json['surah']);
    final ayahNo = json['ayahNo'];

    return Ayat(
      id: json['_id'],
      ayahNo: ayahNo,
      text: json['text'],
      translationText: json['translationText']?.toString(),
      translationLanguage: json['translationLanguage']?.toString(),
      juz: json['juz'],
      hizb: json['hizb'],
      hizbQuarter: json['hizbQuarter'],
      page: resolveCanonicalMushafPage(
        surahId: surah.id,
        ayahNo: ayahNo is int ? ayahNo : int.tryParse('$ayahNo') ?? 0,
        fallbackPage: json['page'] as int?,
      ),
      wordCount: json['wordCount'],
      letterCount: json['letterCount'],
      weight: json['weight'],
      showAyahText: json['showAyahText'] ?? true,
      ayahType: json['ayahType'],
      evaluationType: json['evaluationType']?.toString(),
      schoolLevels: json['schoolLevels'] != null
          ? (json['schoolLevels'] as List)
              .map((e) => SchoolLevel.fromJson(e))
              .toList()
          : [],
        subjects: json['subjects'] != null
          ? (json['subjects'] as List)
            .map((item) => item.toString())
            .toList()
          : [],
      surah: surah,
      userEvaluation: json['userEvaluation'] == null
          ? null
          : UserEvaluation.fromJson(json['userEvaluation']),
      teacherRecommendations: json['teacherRecommendations'] != null
          ? (json['teacherRecommendations'] as List)
              .map((e) => TeacherRecommendation.fromJson(e))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': _id,
      'ayahNo': ayahNo,
      'text': text,
      'translationText': translationText,
      'translationLanguage': translationLanguage,
      'juz': juz,
      'hizb': hizb,
      'hizbQuarter': hizbQuarter,
      'page': page,
      'wordCount': wordCount,
      'letterCount': letterCount,
      'weight': weight,
      'showAyahText': showAyahText,
      'ayahType': ayahType,
      'evaluationType': evaluationType,
      'subjects': subjects,
    };
  }

  @override
  String toString() {
    return 'Ayat(text: $text, translationLanguage: $translationLanguage)';
  }

  bool get hasTeacherRecommendations => teacherRecommendations.isNotEmpty;
}
