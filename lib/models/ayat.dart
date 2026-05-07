import 'package:sahifaty/core/utils/surah_localization.dart';

import 'package:sahifaty/models/school_level.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/models/teacher_recommendation.dart';
import 'package:sahifaty/models/user_evaluation.dart';

class Ayat {
  int? _id;
  String text;
  int ayahNo;
  int juz;
  int hizb;
  int? hizbQuarter;
  int? page;
  int? wordCount;
  int? letterCount;
  double? weight;
  String? ayahType;
  List<SchoolLevel>? schoolLevels;
  List<String>? subjects;
  Surah surah;
  UserEvaluation? userEvaluation;
  List<TeacherRecommendation> teacherRecommendations;

  Ayat({
    int? id,
    required this.text,
    required this.ayahNo,
    required this.juz,
    required this.hizb,
    this.hizbQuarter,
    this.page,
    this.wordCount,
    this.letterCount,
    this.weight,
    this.ayahType,
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
      ayahType: json['ayahType'],
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
      'juz': juz,
      'hizb': hizb,
      'hizbQuarter': hizbQuarter,
      'page': page,
      'wordCount': wordCount,
      'letterCount': letterCount,
      'weight': weight,
      'ayahType': ayahType,
      'subjects': subjects,
    };
  }

  @override
  String toString() {
    return 'Ayat(text: $text)';
  }

  bool get hasTeacherRecommendations => teacherRecommendations.isNotEmpty;
}
