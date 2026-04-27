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
  }) : username = (username ?? '').trim();

  // from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'];

    return User(
      id: rawId is int ? rawId : int.tryParse('${rawId ?? 0}') ?? 0,
      username: (json['username'] ?? '') as String,
      email: json['email'],
      userRoleId: json['userRoleId'] ?? json['roleNum'],
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
    };
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, userRoleId: $userRoleId, licenseStatus: $licenseStatus, gender: $gender, birthYear: $birthYear, countryCode: $countryCode, country: $country, city: $city, state: $state, mobile: $mobile, educationLevel: $educationLevel, workType: $workType, specializationType: $specializationType)';
  }
}
