import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api.dart';
import '../core/typography/typography_config.dart';

/// Loads the typography config for the user app from the central API and
/// caches it locally so the app can apply consistent styling offline.
///
/// Mirrors [TranslationLibraryService] in storage strategy:
/// - Cached payload JSON in SharedPreferences (key: `typography_config_<app>`).
/// - Bundled asset seed at `assets/json/typography_<app>.json` as fallback.
/// - Network is never touched in [loadCachedOrSeed]; remote refresh runs in
///   [refreshInBackground].
class TypographyConfigService {
  TypographyConfigService._();

  static const String appKey = 'frontend-users-ui';
  static const Duration _httpTimeout = Duration(seconds: 12);
  static const String _cacheKey = 'typography_config_frontend-users-ui';
  static const String _seedAssetPath =
      'assets/json/typography_frontend-users-ui.json';

  /// Loads the typography config for use at startup.
  ///
  /// Resolution order:
  /// 1. Cached payload from a previous successful fetch.
  /// 2. Bundled asset seed.
  /// 3. [TypographyConfig.defaults].
  static Future<TypographyConfig> loadCachedOrSeed() async {
    final cached = await _readCached();
    if (cached != null) {
      return cached;
    }
    final seed = await _readSeed();
    return seed ?? TypographyConfig.defaults;
  }

  /// Refreshes the config from the API in the background. On success the
  /// cache is updated and [onUpdated] is invoked with the new config.
  /// Failures are swallowed so the app keeps using the cached/seed copy.
  static Future<void> refreshInBackground({
    required void Function(TypographyConfig config) onUpdated,
  }) async {
    try {
      final fetched = await _fetchRemote();
      if (fetched == null) return;
      await _writeCache(fetched);
      onUpdated(fetched);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'TypographyConfigService: refresh failed: $error\n$stackTrace',
        );
      }
    }
  }

  // ---- Internals -----------------------------------------------------------

  static Future<TypographyConfig?> _readCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    return _decode(raw);
  }

  static Future<TypographyConfig?> _readSeed() async {
    try {
      final raw = await rootBundle.loadString(_seedAssetPath);
      return _decode(raw);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'TypographyConfigService: no asset seed at $_seedAssetPath: $error',
        );
      }
      return null;
    }
  }

  static Future<TypographyConfig?> _fetchRemote() async {
    final uri = Uri.parse(ApiConfig.endpoint('typography-config/$appKey'));
    final response = await http.get(uri).timeout(_httpTimeout);
    if (response.statusCode != 200) return null;
    return _decode(response.body);
  }

  static Future<void> _writeCache(TypographyConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, json.encode(config.toJson()));
  }

  static TypographyConfig? _decode(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      return TypographyConfig.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('TypographyConfigService: failed to decode payload: $error');
      }
      return null;
    }
  }
}
