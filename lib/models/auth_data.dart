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
    // الشكل (a): حقول المستخدم على مستوى الجذر مع توكين مباشر
    if (json.containsKey('id') || json.containsKey('username')) {
      userData = User.fromJson(json);
      return AuthData(
          accessToken: json['accessToken'] ?? json['token'],
          refreshToken: json['refreshToken'],
          user: userData);
    }
    // الشكل (b): كائن المستخدم متداخل داخل مفتاح user
    if (json.containsKey('user') && json['user'] is Map<String, dynamic>) {
      userData = User.fromJson(json['user'] as Map<String, dynamic>);
      return AuthData(
        accessToken: json['accessToken'] ?? json['token'],
        refreshToken: json['refreshToken'],
        user: userData,
      );
    }
    // الشكل (c): استجابة بدون كائن مستخدم (توكين فقط)
    return AuthData(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
    );
  }

  @override
  String toString() {
    return 'AuthData(accessToken: $accessToken, refreshToken: $refreshToken, user: ${user.toString()})';
  }
}
