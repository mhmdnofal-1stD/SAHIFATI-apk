import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class PushNotificationsService {
  static final PushNotificationsService _instance =
      PushNotificationsService._internal();

  factory PushNotificationsService() => _instance;

  PushNotificationsService._internal();

  bool _initialized = false;

  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await Firebase.initializeApp();

    final messaging = FirebaseMessaging.instance;

    if (!kIsWeb) {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_handleOpenedMessage(message)),
    );

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_handleOpenedMessage(initialMessage));
    }

    _initialized = true;
  }

  Future<String?> getToken() async {
    if (!_initialized) {
      await ensureInitialized();
    }

    return FirebaseMessaging.instance.getToken();
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final ctaUrl = _extractCtaUrl(message.data);
    if (ctaUrl == null) {
      return;
    }

    final uri = Uri.tryParse(ctaUrl);
    if (uri == null) {
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Push CTA launch failed: $error');
    }
  }

  String? _extractCtaUrl(Map<String, dynamic> data) {
    final rawValue = data['ctaUrl'] ?? data['cta_url'];
    if (rawValue is! String) {
      return null;
    }

    final trimmed = rawValue.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}