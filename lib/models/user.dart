class User {
  int id;
  String fullName;
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
    required this.fullName,
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
  });

  // from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'];

    return User(
      id: rawId is int ? rawId : int.tryParse('${rawId ?? 0}') ?? 0,
      fullName: json['fullName'],
      email: json['email'],
      userRoleId: json['userRoleId'],
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
      'fullName': fullName,
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
    return 'User(id: $id, fullName: $fullName, email: $email, userRoleId: $userRoleId, licenseStatus: $licenseStatus, gender: $gender, birthYear: $birthYear, countryCode: $countryCode, country: $country, city: $city, state: $state, mobile: $mobile, educationLevel: $educationLevel, workType: $workType, specializationType: $specializationType)';
  }
}
