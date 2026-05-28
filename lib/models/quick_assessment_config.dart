class ContentItem {
  final String type; // 'ayatRange', 'surah', 'juz', 'hizb', 'hizbQuarter'
  final Map<String, String>? customLabel; // عنوان مخصص اختياري (مثل "آية الكرسي")
  final bool showAyahText;
  final int? surahId;
  final int? startAyah;
  final int? endAyah;
  final int? juz;
  final int? hizb;
  final int? hizbQuarter;

  ContentItem({
    required this.type,
    this.customLabel,
    this.showAyahText = true,
    this.surahId,
    this.startAyah,
    this.endAyah,
    this.juz,
    this.hizb,
    this.hizbQuarter,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      type: json['type'] ?? 'ayatRange',
      customLabel: json['customLabel'] != null 
          ? Map<String, String>.from(json['customLabel'])
          : null,
      showAyahText: json['showAyahText'] ?? true,
      surahId: json['surahId'],
      startAyah: json['startAyah'],
      endAyah: json['endAyah'],
      juz: json['juz'],
      hizb: json['hizb'],
      hizbQuarter: json['hizbQuarter'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (customLabel != null) 'customLabel': customLabel,
      'showAyahText': showAyahText,
      if (surahId != null) 'surahId': surahId,
      if (startAyah != null) 'startAyah': startAyah,
      if (endAyah != null) 'endAyah': endAyah,
      if (juz != null) 'juz': juz,
      if (hizb != null) 'hizb': hizb,
      if (hizbQuarter != null) 'hizbQuarter': hizbQuarter,
    };
  }
}

class AssessmentLevel {
  final Map<String, String> name;
  final List<ContentItem> content;
  final String? evaluationType; // 'memorization' or 'comprehension'

  AssessmentLevel({
    required this.name,
    required this.content,
    this.evaluationType,
  });

  factory AssessmentLevel.fromJson(Map<String, dynamic> json) {
    return AssessmentLevel(
      name: json['name'] != null
          ? Map<String, String>.from(json['name'])
          : {'ar': ''},
      content: json['content'] != null
          ? (json['content'] as List)
              .map((item) => ContentItem.fromJson(item))
              .toList()
          : [],
      evaluationType: json['evaluationType'],
    );
  }

  String getNameAr() {
    return name['ar'] ?? '';
  }
}

class QuickAssessmentConfig {
  final int id;
  final bool isEnabled;
  final Map<String, String>? cardTitle;
  final List<AssessmentLevel>? levels;
  final bool showResultsImmediately;
  final List<int>? evaluationIds;

  QuickAssessmentConfig({
    required this.id,
    required this.isEnabled,
    this.cardTitle,
    this.levels,
    required this.showResultsImmediately,
    this.evaluationIds,
  });

  factory QuickAssessmentConfig.fromJson(Map<String, dynamic> json) {
    return QuickAssessmentConfig(
      id: json['_id'] ?? 0,
      isEnabled: json['isEnabled'] ?? true,
      cardTitle: json['cardTitle'] != null
          ? Map<String, String>.from(json['cardTitle'])
          : null,
      levels: json['levels'] != null
          ? (json['levels'] as List)
              .map((level) => AssessmentLevel.fromJson(level))
              .toList()
          : null,
      showResultsImmediately: json['showResultsImmediately'] ?? true,
      evaluationIds: json['evaluationIds'] != null
          ? List<int>.from(json['evaluationIds'])
          : null,
    );
  }

  String getCardTitleAr() {
    return cardTitle?['ar'] ?? 'تقييم سريع';
  }
}
