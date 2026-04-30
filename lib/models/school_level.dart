import 'package:sahifaty/models/school_level_content.dart';

class SchoolLevel {
  String? _id;
  int? schoolId;
  String? schoolName;
  int? level;
  Map<String, dynamic>? name;
  List<SchoolLevelContent> content;

  SchoolLevel({
    String? id,
    this.schoolId,
    this.name,
    this.schoolName,
    this.level,
    required this.content,
  }) : _id = id;

  String? get id => _id;

  static int? _parseInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _parseStringOrLocalized(dynamic value) {
    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (value is Map) {
      for (final key in const ['ar', 'en']) {
        final candidate = value[key];
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
      for (final candidate in value.values) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
    }
    return null;
  }

  static Map<String, dynamic>? _parseLocalizedName(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String && value.trim().isNotEmpty) {
      return {
        'ar': value.trim(),
        'en': value.trim(),
      };
    }
    return null;
  }

  factory SchoolLevel.fromJson(Map<String, dynamic> json) {
    return SchoolLevel(
      id: json['_id']?.toString(),
      schoolId: _parseInt(json['schoolId']),
      schoolName: _parseStringOrLocalized(json['schoolName']),
      level: _parseInt(json['level']),
      name: _parseLocalizedName(json['name']),
      content: json['content'] != null
          ? (json['content'] as List)
              .map((e) => SchoolLevelContent.fromJson(e))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': _id,
      'schoolId': schoolId,
      'schoolName': schoolName,
      'level': level,
      'name': name,
      'content': content,
    };
  }
}
