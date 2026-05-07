int? _parseUserRoleId(dynamic rawRole) {
  if (rawRole is num) {
    return rawRole.toInt();
  }

  switch (rawRole?.toString().trim().toLowerCase()) {
    case '0':
    case 'student':
      return 0;
    case '1':
    case 'supervisor':
      return 1;
    case '2':
    case 'admin':
      return 2;
    case '3':
    case 'researcher':
      return 3;
    case '4':
    case 'reviewer':
      return 4;
    case '5':
    case 'admitter':
      return 5;
    default:
      return null;
  }
}

class User {
  int id;
  String username;
  String email;
  int? userRoleId;
  String? licenseStatus;
  String? gender;
  int? birthYear;
  int? countryCode;
  String? country;
  String? city;
  String? state;
  String? mobile;
  String? educationLevel;
  String? workType;
  String? specializationType;
  // Fields present in API schema that were previously silently dropped
  String? firstName;
  String? familyName;
  String? nationality;
  String? language;
  bool? emailVerified;
  // Reading display preferences — stored in API and synced on profile fetch
  bool showMemorizationColors;
  bool showComprehensionUnderline;
  List<String> allowedSubjectKeys;

  User({
    required this.id,
    String? username,
    required this.email,
    this.userRoleId,
    this.licenseStatus,
    this.gender,
    this.birthYear,
    this.countryCode,
    this.country,
    this.city,
    this.state,
    this.mobile,
    this.educationLevel,
    this.workType,
    this.specializationType,
    this.firstName,
    this.familyName,
    this.nationality,
    this.language,
    this.emailVerified,
    this.showMemorizationColors = true,
    this.showComprehensionUnderline = true,
    this.allowedSubjectKeys = const [],
  }) : username = (username ?? '').trim();

  // from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'];

    return User(
      id: rawId is int ? rawId : int.tryParse('${rawId ?? 0}') ?? 0,
      username: (json['username'] ?? '') as String,
      email: json['email'],
      userRoleId: _parseUserRoleId(
        json['userRoleId'] ?? json['roleNum'] ?? json['role'],
      ),
      licenseStatus: json['licenseStatus'] as String?,
      gender: json['gender'] as String?,
      birthYear: json['birthYear'] as int?,
      countryCode: json['countryCode'] as int?,
      country: json['country'] as String?,
      city: (json['city'] as String?) ?? (json['state'] as String?),
      state: json['state'] as String?,
      mobile: json['mobile'] as String?,
      educationLevel: json['educationLevel'] as String?,
      workType: json['workType'] as String?,
      specializationType: json['specializationType'] as String?,
      firstName: json['firstName'] as String?,
      familyName: json['familyName'] as String?,
      nationality: json['nationality'] as String?,
      language: json['language'] as String?,
      emailVerified: json['emailVerified'] as bool?,
      showMemorizationColors:
          json['showMemorizationColors'] as bool? ?? true,
      showComprehensionUnderline:
          json['showComprehensionUnderline'] as bool? ?? true,
      allowedSubjectKeys: List<String>.from(
          (json['allowedSubjectKeys'] as List?) ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'userRoleId': userRoleId,
      'licenseStatus': licenseStatus,
      'gender': gender,
      'birthYear': birthYear,
      'countryCode': countryCode,
      'country': country,
      'city': city,
      'state': state,
      'mobile': mobile,
      'educationLevel': educationLevel,
      'workType': workType,
      'specializationType': specializationType,
      'firstName': firstName,
      'familyName': familyName,
      'nationality': nationality,
      'language': language,
      'emailVerified': emailVerified,
      'showMemorizationColors': showMemorizationColors,
      'showComprehensionUnderline': showComprehensionUnderline,
      'allowedSubjectKeys': allowedSubjectKeys,
    };
  }

  /// Display name: prefers firstName+familyName when available, falls back to username.
  String get displayName {
    final first = firstName?.trim() ?? '';
    final family = familyName?.trim() ?? '';
    if (first.isNotEmpty || family.isNotEmpty) {
      return '$first $family'.trim();
    }
    return username;
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, userRoleId: $userRoleId, '
        'licenseStatus: $licenseStatus, gender: $gender, birthYear: $birthYear, '
        'countryCode: $countryCode, country: $country, city: $city, state: $state, '
        'mobile: $mobile, educationLevel: $educationLevel, workType: $workType, '
        'specializationType: $specializationType, firstName: $firstName, '
        'familyName: $familyName, nationality: $nationality, '
        'showMemorizationColors: $showMemorizationColors, '
        'showComprehensionUnderline: $showComprehensionUnderline)';
  }
}
