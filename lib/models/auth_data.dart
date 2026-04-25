import 'package:sahifaty/models/user.dart';

class AuthData {
  String? accessToken;
  String? refreshToken;
  User? user;

  AuthData({
    this.accessToken,
    this.refreshToken,
    this.user,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    User? userData;
    if (json.containsKey('id') || json.containsKey('fullName')) {
      userData = User(
        id: json['id'],
        fullName: json['fullName'] ?? '',
        email: json['email'] ?? '',
        userRoleId: json['userRoleId'],
        licenseStatus: json['licenseStatus'] as String?,
      );
      return AuthData(
          accessToken: json['token'],
          refreshToken: json['refreshToken'],
          user: userData);
    } else {
      return AuthData(
        accessToken: json['accessToken'],
        refreshToken: json['refreshToken'],
      );
    }
  }

  @override
  String toString() {
    return 'AuthData(accessToken: $accessToken, refreshToken: $refreshToken, user: ${user.toString()})';
  }
}
