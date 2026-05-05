import 'package:sahifaty/models/school_level.dart';

class School {
  int? _id;
  Map <String, dynamic> schoolName;
  List<SchoolLevel> levels;

  School({
    int? id,
    required this.schoolName,
    required this.levels,
  }) : _id = id;

  int? get id => _id;

  static List<SchoolLevel> _parseLevels(
    List<dynamic>? rawLevels, {
    required int? schoolId,
    required Map<String, dynamic> schoolName,
  }) {
    if (rawLevels == null) {
      return [];
    }

    return rawLevels.asMap().entries.map((entry) {
      final index = entry.key;
      final rawLevel = Map<String, dynamic>.from(entry.value as Map);
      rawLevel['schoolId'] ??= schoolId;
      rawLevel['schoolName'] ??= schoolName;
      rawLevel['level'] ??= index + 1;
      return SchoolLevel.fromJson(rawLevel);
    }).toList();
  }

  factory School.fromJson(Map<String, dynamic> json) {
    final parsedSchoolName = Map<String, dynamic>.from(
      (json['schoolName'] as Map?) ?? const <String, dynamic>{},
    );
    return School(
      id: json['_id'],
      schoolName: parsedSchoolName,
      levels: _parseLevels(
        json['levels'] as List<dynamic>?,
        schoolId: json['_id'] as int?,
        schoolName: parsedSchoolName,
      ),
    );
  }


  Map<String, dynamic> toMap() {
    return {
      '_id': _id,
      'schoolName': schoolName,
      'levels': levels,
    };
  }
}
