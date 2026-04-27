class TeacherRecommendationTeacher {
  final int id;
  final String? firstName;
  final String? familyName;
  final String? username;
  final String? email;

  const TeacherRecommendationTeacher({
    required this.id,
    this.firstName,
    this.familyName,
    this.username,
    this.email,
  });

  factory TeacherRecommendationTeacher.fromJson(Map<String, dynamic> json) {
    return TeacherRecommendationTeacher(
      id: json['_id'] ?? json['id'] ?? 0,
      firstName: json['firstName'],
      familyName: json['familyName'],
      username: json['username'],
      email: json['email'],
    );
  }

  String get displayName {
    final user = username?.trim();
    if (user != null && user.isNotEmpty) {
      return user;
    }

    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      return mail;
    }

    final combined = [
      firstName?.trim(),
      familyName?.trim(),
    ].where((value) => value != null && value.isNotEmpty).join(' ');
    if (combined.isNotEmpty) {
      return combined;
    }

    return 'Teacher #$id';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'familyName': familyName,
      'username': username,
      'email': email,
    };
  }
}

class TeacherRecommendation {
  final int id;
  final int teacherId;
  final int studentId;
  final int ayahId;
  final String source;
  final String status;
  final String notified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final TeacherRecommendationTeacher? teacher;

  const TeacherRecommendation({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.ayahId,
    required this.source,
    required this.status,
    required this.notified,
    this.createdAt,
    this.updatedAt,
    this.teacher,
  });

  factory TeacherRecommendation.fromJson(Map<String, dynamic> json) {
    return TeacherRecommendation(
      id: json['_id'] ?? json['id'] ?? 0,
      teacherId: json['teacherId'] ?? 0,
      studentId: json['studentId'] ?? 0,
      ayahId: json['ayahId'] ?? 0,
      source: json['source'] ?? 'teacher',
      status: json['status'] ?? 'active',
      notified: json['notified'] ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      teacher: json['teacher'] is Map<String, dynamic>
          ? TeacherRecommendationTeacher.fromJson(json['teacher'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacherId': teacherId,
      'studentId': studentId,
      'ayahId': ayahId,
      'source': source,
      'status': status,
      'notified': notified,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'teacher': teacher?.toJson(),
    };
  }
}
