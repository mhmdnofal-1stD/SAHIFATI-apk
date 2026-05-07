import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api.dart';
import 'ayah_translation_library_service.dart';

/// Loads translation bundles for the user app from the central translation
/// library API and caches them locally so the app reads strings offline.
///
/// Storage strategy:
/// - Bundle JSON per language is cached as a single string in SharedPreferences
///   (key: `translation_bundle_<lang>`).
/// - Bundle metadata (version + updatedAt) is cached separately
///   (key: `translation_bundle_meta_<lang>`).
/// - On first launch with no cache and no network, the bundled assets
///   (`assets/json/intl_<lang>.json`) act as the seed fallback.
class TranslationLibraryService {
  TranslationLibraryService._();

  static const String appKey = 'frontend-users-ui';
  static const Duration _httpTimeout = Duration(seconds: 12);
  static const Duration _prefsTimeout = Duration(seconds: 2);
  static const String _cachePrefix = 'translation_bundle_';
  static const String _metaPrefix = 'translation_bundle_meta_';

  /// Loads the translations map for [languageCode] for use at startup.
  ///
  /// Resolution order:
  /// 1. Cached bundle from a previous successful fetch.
  /// 2. Bundled assets seed (`assets/json/intl_<lang>.json`) when available.
  /// 3. Empty map.
  ///
  /// Network is never touched here; remote refresh is performed separately by
  /// [refreshInBackground].
  static Future<Map<String, String>> loadCachedOrSeed(
    String languageCode,
    {
    bool includeAyahSeed = true,
  }
  ) async {
    final seed = await _loadAssetSeed(languageCode);
    final cached = await _readCachedBundle(languageCode);
    if (!includeAyahSeed) {
      if (cached != null && cached.isNotEmpty) {
        return _mergeBundles(seed, cached);
      }

      return seed;
    }

    final ayahSeed = await AyahTranslationLibraryService.loadSeed(languageCode);
    if (cached != null && cached.isNotEmpty) {
      return _mergeBundles(_mergeBundles(seed, cached), ayahSeed);
    }

    return _mergeBundles(seed, ayahSeed);
  }

  /// Refreshes one or more language bundles from the API in the background.
  ///
  /// On success, the cache is updated and [onUpdated] is invoked with the
  /// language code and the freshly loaded translations map.
  ///
  /// Failures are logged in debug mode and silently ignored otherwise so
  /// they never block the app.
  static Future<void> refreshInBackground({
    required Iterable<String> languageCodes,
    required void Function(String languageCode, Map<String, String> translations)
        onUpdated,
  }) async {
    for (final languageCode in languageCodes) {
      try {
        final fetched = await _fetchBundle(languageCode);
        if (fetched == null) {
          continue;
        }

        final seed = await _loadAssetSeed(languageCode);
        final ayahSeed = await AyahTranslationLibraryService.loadSeed(
          languageCode,
        );
        final mergedTranslations = _mergeBundles(
          _mergeBundles(seed, fetched.translations),
          ayahSeed,
        );

        await _writeCachedBundle(
          languageCode,
          translations: mergedTranslations,
          version: fetched.version,
          updatedAt: fetched.updatedAt,
        );

        onUpdated(languageCode, mergedTranslations);
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            'TranslationLibraryService: refresh failed for $languageCode: $error\n$stackTrace',
          );
        }
      }
    }
  }

  static Future<Map<String, String>?> _readCachedBundle(
    String languageCode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      final raw = prefs.getString('$_cachePrefix$languageCode');
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final decoded = json.decode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint(
          'TranslationLibraryService: timed out reading cached bundle for $languageCode',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'TranslationLibraryService: cached bundle for $languageCode is corrupt: $error',
        );
      }
    }

    return null;
  }

  static Future<Map<String, String>> _loadAssetSeed(
    String languageCode,
  ) async {
    final assetPath = 'assets/json/intl_$languageCode.json';
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'TranslationLibraryService: no asset seed for $languageCode at $assetPath: $error',
        );
      }
    }

    return <String, String>{};
  }

  static Map<String, String> _mergeBundles(
    Map<String, String> seed,
    Map<String, String> override,
  ) {
    if (seed.isEmpty) {
      return Map<String, String>.from(override);
    }
    return <String, String>{...seed, ...override};
  }

  static Future<_FetchedBundle?> _fetchBundle(String languageCode) async {
    final uri = Uri.parse(
      ApiConfig.endpoint('translation-library/$appKey?language=$languageCode'),
    );

    final response = await http.get(uri).timeout(_httpTimeout);
    if (response.statusCode != 200) {
      return null;
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) {
      return null;
    }

    final translationsRaw = decoded['translations'];
    if (translationsRaw is! Map) {
      return null;
    }

    final translations = translationsRaw.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );

    return _FetchedBundle(
      translations: translations,
      version: (decoded['version'] is num)
          ? (decoded['version'] as num).toInt()
          : null,
      updatedAt: decoded['updatedAt']?.toString(),
    );
  }

  static Future<void> _writeCachedBundle(
    String languageCode, {
    required Map<String, String> translations,
    int? version,
    String? updatedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_cachePrefix$languageCode',
      json.encode(translations),
    );
    await prefs.setString(
      '$_metaPrefix$languageCode',
      json.encode({
        'version': version,
        'updatedAt': updatedAt,
      }),
    );
  }
}

class _FetchedBundle {
  _FetchedBundle({
    required this.translations,
    required this.version,
    required this.updatedAt,
  });

  final Map<String, String> translations;
  final int? version;
  final String? updatedAt;
}
