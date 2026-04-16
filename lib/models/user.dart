class User {
  int id;
  String fullName;
  String email;
  int? userRoleId;


  User({
    required this.id,
    required this.fullName,
    required this.email,
    this.userRoleId,
  });


  // from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
      userRoleId: json['userRoleId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'userRoleId': userRoleId,
    };
  }

  @override
  String toString() {
    return 'User(id: $id, fullName: $fullName, email: $email, userRoleId: $userRoleId)';
  }
}
