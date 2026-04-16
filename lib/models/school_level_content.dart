class SchoolLevelContent {
  String? _id;
  String type;
  int? surahId;
  int? hizb;
  int? hizbQuarter;
  int? startAyah;
  int? endAyah;
  int? juz;

  SchoolLevelContent({
    String? id,
    required this.type,
    this.surahId,
    this.hizb,
    this.hizbQuarter,
    this.startAyah,
    this.endAyah,
    this.juz,
  }) : _id = id;

  String? get id => _id;

  String get cacheKey {
    return [
      _id ?? '',
      type,
      surahId?.toString() ?? '',
      hizb?.toString() ?? '',
      hizbQuarter?.toString() ?? '',
      startAyah?.toString() ?? '',
      endAyah?.toString() ?? '',
      juz?.toString() ?? '',
    ].join('|');
  }

  factory SchoolLevelContent.fromJson(Map<String, dynamic> json) {
    return SchoolLevelContent(
        id: json['_id'],
        type: json['type'] ?? json['name'],
        surahId: json['surahId'],
        hizb: json['hizb'],
        hizbQuarter: json['hizbQuarter'],
        startAyah: json['startAyah'],
        endAyah: json['endAyah'],
        juz: json['juz']);
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': _id,
      'name': type,
      'surahId': surahId,
      'hizb': hizb,
      'hizbQuarter': hizbQuarter,
      'startAyah': startAyah,
      'endAyah': endAyah,
      'juz': juz
    };
  }
}
