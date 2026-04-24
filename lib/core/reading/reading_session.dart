import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/models/surah.dart';

class ReadingSession {
  const ReadingSession({
    required this.userId,
    required this.surah,
    required this.filterTypeId,
    required this.shouldAutoResume,
    this.juz,
    this.hizb,
    this.currentPage,
    this.currentHizbQuarter,
  });

  final int userId;
  final Surah surah;
  final int filterTypeId;
  final int? juz;
  final int? hizb;
  final int? currentPage;
  final int? currentHizbQuarter;
  final bool shouldAutoResume;

  ReadingSession copyWith({
    int? userId,
    Surah? surah,
    int? filterTypeId,
    int? juz,
    int? hizb,
    int? currentPage,
    int? currentHizbQuarter,
    bool? shouldAutoResume,
  }) {
    return ReadingSession(
      userId: userId ?? this.userId,
      surah: surah ?? this.surah,
      filterTypeId: filterTypeId ?? this.filterTypeId,
      juz: juz ?? this.juz,
      hizb: hizb ?? this.hizb,
      currentPage: currentPage ?? this.currentPage,
      currentHizbQuarter: currentHizbQuarter ?? this.currentHizbQuarter,
      shouldAutoResume: shouldAutoResume ?? this.shouldAutoResume,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'surah': surah.toMap(),
      'filterTypeId': filterTypeId,
      'juz': juz,
      'hizb': hizb,
      'currentPage': currentPage,
      'currentHizbQuarter': currentHizbQuarter,
      'shouldAutoResume': shouldAutoResume,
    };
  }

  factory ReadingSession.fromMap(Map<String, dynamic> map) {
    return ReadingSession(
      userId: map['userId'] as int? ?? 0,
      surah: Surah.fromJson(
        Map<String, dynamic>.from(map['surah'] as Map? ?? const {}),
      ),
      filterTypeId: map['filterTypeId'] as int? ?? FilterTypes.thirds,
      juz: map['juz'] as int?,
      hizb: map['hizb'] as int?,
      currentPage: map['currentPage'] as int?,
      currentHizbQuarter: map['currentHizbQuarter'] as int?,
      shouldAutoResume: map['shouldAutoResume'] as bool? ?? false,
    );
  }

  String pathLabel(bool isArabic) {
    switch (filterTypeId) {
      case FilterTypes.parts:
        return isArabic ? 'الأجزاء' : 'parts';
      case FilterTypes.hizbs:
        return isArabic ? 'الأحزاب' : 'hizbs';
      default:
        return isArabic ? 'الأثلاث' : 'thirds';
    }
  }
}

class ReadingSessionStore {
  static const String storageKey = 'reading_session_v1';

  Future<ReadingSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final data = jsonDecode(raw);
      if (data is! Map) {
        return null;
      }

      return ReadingSession.fromMap(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<ReadingSession?> loadForUser(int? userId) async {
    if (userId == null) {
      return null;
    }

    final session = await load();
    if (session == null || session.userId != userId) {
      return null;
    }

    return session;
  }

  Future<void> save(ReadingSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(session.toMap()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  Future<void> updateAutoResumeForUser(
    int? userId,
    bool shouldAutoResume,
  ) async {
    final session = await loadForUser(userId);
    if (session == null) {
      return;
    }

    await save(
      session.copyWith(
        shouldAutoResume: shouldAutoResume,
      ),
    );
  }

  Future<ReadingSession?> consumePendingAutoResumeForUser(int? userId) async {
    final session = await loadForUser(userId);
    if (session == null || !session.shouldAutoResume) {
      return null;
    }

    await save(
      session.copyWith(
        shouldAutoResume: false,
      ),
    );

    return session.copyWith(shouldAutoResume: false);
  }
}