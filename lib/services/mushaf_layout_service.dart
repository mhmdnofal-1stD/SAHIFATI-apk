import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/reading/mushaf_page_layout.dart';

class MushafLayoutService {
  MushafLayoutService._();

  static const String _assetPath = 'assets/json/mushaf_layout_mushaf5.json';

  static Map<int, MushafPageLayout>? _cache;

  static Future<Map<int, MushafPageLayout>> loadAllPages() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }

    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <int, MushafPageLayout>{};
      }

      final pages = (decoded['pages'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(MushafPageLayout.fromJson)
          .toList(growable: false);

      _cache = <int, MushafPageLayout>{
        for (final page in pages) page.pageNumber: page,
      };
      return _cache!;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'MushafLayoutService: failed to load $_assetPath: '
          '$error\n$stackTrace',
        );
      }
      return const <int, MushafPageLayout>{};
    }
  }

  static Future<MushafPageLayout?> loadPage(int pageNumber) async {
    final pages = await loadAllPages();
    return pages[pageNumber];
  }

  @visibleForTesting
  static void resetCache() {
    _cache = null;
  }
}