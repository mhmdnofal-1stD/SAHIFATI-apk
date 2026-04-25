import 'dart:convert';

import 'package:get/get.dart';

import 'sahifaty_api.dart';

class TeacherSupervisionsService {
  Future<Map<String, dynamic>> previewByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final response = await SahifatyApi().get(
      'teacher-supervisions/preview-by-code/$normalized',
    );
    final body = json.decode(response.body);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body as Map);
    }
    if (response.statusCode == 404) {
      throw 'supervision_scan_code_not_found'.tr;
    }
    throw _extractMessage(body, 'supervision_scan_preview_failed'.tr);
  }

  Future<Map<String, dynamic>> scanByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final response = await SahifatyApi().post(
      url: 'teacher-supervisions/scan-by-code',
      body: {'code': normalized},
    );
    final body = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(body as Map);
    }
    throw _extractMessage(body, 'supervision_scan_send_failed'.tr);
  }

  Future<List<Map<String, dynamic>>> listIncomingRequests() async {
    final response = await SahifatyApi().get(
      'teacher-supervisions/requests/incoming',
    );
    final body = json.decode(response.body);
    if (response.statusCode == 200 && body is List) {
      return body
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    }
    throw _extractMessage(body, 'supervision_requests_load_failed'.tr);
  }

  Future<List<Map<String, dynamic>>> listLinks() async {
    final response = await SahifatyApi().get('teacher-supervisions/links');
    final body = json.decode(response.body);
    if (response.statusCode == 200 && body is List) {
      return body
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    }
    throw _extractMessage(body, 'supervision_links_load_failed'.tr);
  }

  Future<Map<String, dynamic>> getLimits() async {
    final response = await SahifatyApi().get('teacher-supervisions/limits');
    final body = json.decode(response.body);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(body as Map);
    }
    throw _extractMessage(body, 'supervision_limits_load_failed'.tr);
  }

  Future<Map<String, dynamic>> acceptRequest(int requestId) async {
    final response = await SahifatyApi().post(
      url: 'teacher-supervisions/requests/$requestId/accept',
      body: const {},
    );
    final body = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(body as Map);
    }
    if (response.statusCode == 409 && body is Map) {
      final code = body['code'];
      if (code == 'TEACHER_LIMIT_REACHED') {
        throw const TeacherLimitReachedException();
      }
      if (code == 'STUDENT_LIMIT_REACHED') {
        throw StudentLimitReachedException(
          (body['current'] as num?)?.toInt() ?? 0,
          (body['max'] as num?)?.toInt() ?? 5,
        );
      }
    }
    throw _extractMessage(body, 'supervision_accept_failed'.tr);
  }

  Future<Map<String, dynamic>> acceptRequestWithRemove(
    int requestId,
    int removeLinkId,
  ) async {
    final response = await SahifatyApi().post(
      url: 'teacher-supervisions/requests/$requestId/accept-with-remove',
      body: {'removeLinkId': removeLinkId},
    );
    final body = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(body as Map);
    }
    throw _extractMessage(body, 'supervision_accept_failed'.tr);
  }

  Future<Map<String, dynamic>> rejectRequest(
    int requestId, {
    String? reason,
  }) async {
    final response = await SahifatyApi().post(
      url: 'teacher-supervisions/requests/$requestId/reject',
      body: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason},
    );
    final body = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(body as Map);
    }
    throw _extractMessage(body, 'supervision_reject_failed'.tr);
  }

  Future<Map<String, dynamic>> startOneTimeReview(int requestId) async {
    final response = await SahifatyApi().post(
      url: 'teacher-supervisions/requests/$requestId/one-time-review',
      body: const {},
    );
    final body = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(body as Map);
    }
    throw _extractMessage(body, 'supervision_one_time_review_failed'.tr);
  }

  Future<Map<String, dynamic>> closeOneTimeReview(int sessionId) async {
    final response = await SahifatyApi().post(
      url: 'teacher-supervisions/one-time-reviews/$sessionId/close',
      body: const {},
    );
    final body = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(body as Map);
    }
    throw _extractMessage(body, 'supervision_one_time_review_close_failed'.tr);
  }

  String _extractMessage(dynamic body, String fallback) {
    if (body is Map) {
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
    }
    return fallback;
  }
}

class TeacherLimitReachedException implements Exception {
  const TeacherLimitReachedException();
}

class StudentLimitReachedException implements Exception {
  const StudentLimitReachedException(this.current, this.max);
  final int current;
  final int max;
}