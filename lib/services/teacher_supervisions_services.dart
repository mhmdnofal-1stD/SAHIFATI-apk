import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

import 'offline_assessment_store.dart';
import 'sahifaty_api.dart';
import 'secure_session_storage.dart';

class TeacherSupervisionsService {
  final SahifatyApi _api = SahifatyApi();
  final OfflineAssessmentStore _offlineStore = OfflineAssessmentStore();

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<String> _resolveScopeKey() async {
    final accountKey = await SecureSessionStorage.readActiveAccountKey();
    if (accountKey != null && accountKey.trim().isNotEmpty) {
      return accountKey.trim();
    }
    return 'default';
  }

  Future<Map<String, dynamic>> previewByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final response = await _api.get(
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
    await _throwIfOfflineWrite();

    final normalized = code.trim().toUpperCase();
    final response = await _api.post(
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
    final scopeKey = await _resolveScopeKey();
    if (!await _isOnline()) {
      final cached = await _offlineStore.getCachedSupervisionRequestsJson(
        scopeKey: scopeKey,
      );
      if (cached != null && cached.isNotEmpty) {
        return _decodeListOfMaps(cached);
      }
      throw 'supervision_requests_load_failed'.tr;
    }

    final response = await _api.get('teacher-supervisions/requests/incoming');
    final body = json.decode(response.body);
    if (response.statusCode == 200 && body is List) {
      await _offlineStore.cacheSupervisionRequestsJson(
        scopeKey: scopeKey,
        rawJson: response.body,
      );
      return _decodeListBody(body);
    }
    throw _extractMessage(body, 'supervision_requests_load_failed'.tr);
  }

  Future<List<Map<String, dynamic>>> listLinks() async {
    final scopeKey = await _resolveScopeKey();
    if (!await _isOnline()) {
      final cached = await _offlineStore.getCachedSupervisionLinksJson(
        scopeKey: scopeKey,
      );
      if (cached != null && cached.isNotEmpty) {
        return _decodeListOfMaps(cached);
      }
      throw 'supervision_links_load_failed'.tr;
    }

    final response = await _api.get('teacher-supervisions/links');
    final body = json.decode(response.body);
    if (response.statusCode == 200 && body is List) {
      await _offlineStore.cacheSupervisionLinksJson(
        scopeKey: scopeKey,
        rawJson: response.body,
      );
      return _decodeListBody(body);
    }
    throw _extractMessage(body, 'supervision_links_load_failed'.tr);
  }

  Future<Map<String, dynamic>> getLimits() async {
    final scopeKey = await _resolveScopeKey();
    if (!await _isOnline()) {
      final cached = await _offlineStore.getCachedSupervisionLimitsJson(
        scopeKey: scopeKey,
      );
      if (cached != null && cached.isNotEmpty) {
        return _decodeMapBody(json.decode(cached));
      }
      throw 'supervision_limits_load_failed'.tr;
    }

    final response = await _api.get('teacher-supervisions/limits');
    final body = json.decode(response.body);
    if (response.statusCode == 200) {
      await _offlineStore.cacheSupervisionLimitsJson(
        scopeKey: scopeKey,
        rawJson: response.body,
      );
      return _decodeMapBody(body);
    }
    throw _extractMessage(body, 'supervision_limits_load_failed'.tr);
  }

  Future<Map<String, dynamic>> acceptRequest(int requestId) async {
    await _throwIfOfflineWrite();

    final response = await _api.post(
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
    await _throwIfOfflineWrite();

    final response = await _api.post(
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
    await _throwIfOfflineWrite();

    final response = await _api.post(
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
    await _throwIfOfflineWrite();

    final response = await _api.post(
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
    await _throwIfOfflineWrite();

    final response = await _api.post(
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

  Future<void> _throwIfOfflineWrite() async {
    if (!await _isOnline()) {
      throw Exception('offline_write_not_supported');
    }
  }

  List<Map<String, dynamic>> _decodeListOfMaps(String rawJson) {
    return _decodeListBody(json.decode(rawJson));
  }

  List<Map<String, dynamic>> _decodeListBody(dynamic body) {
    if (body is! List) {
      throw 'supervision_list_cache_invalid';
    }

    return body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Map<String, dynamic> _decodeMapBody(dynamic body) {
    if (body is! Map) {
      throw 'supervision_limits_cache_invalid';
    }
    return Map<String, dynamic>.from(body);
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