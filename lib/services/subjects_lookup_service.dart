import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sahifaty_api.dart';

class SubjectHierarchyItem {
  const SubjectHierarchyItem({
    required this.key,
    required this.name,
    this.nameAr,
  });

  final String key;
  final Map<String, String> name;
  final String? nameAr;

  factory SubjectHierarchyItem.fromJson(Map<String, dynamic> json) {
    final localizedName = <String, String>{};
    final rawName = json['name'];

    if (rawName is Map) {
      for (final entry in rawName.entries) {
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty) {
          localizedName[entry.key.toString()] = value.trim();
        }
      }
    }

    return SubjectHierarchyItem(
      key: json['_key']?.toString() ?? '',
      name: localizedName,
      nameAr: json['nameAr']?.toString(),
    );
  }

  String displayName(String localeCode) {
    final preferred = name[localeCode]?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }

    final arabic = name['ar']?.trim();
    if (arabic != null && arabic.isNotEmpty) {
      return arabic;
    }

    final english = name['en']?.trim();
    if (english != null && english.isNotEmpty) {
      return english;
    }

    for (final value in name.values) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return nameAr?.trim() ?? '';
  }
}

class SubjectsLookupService {
  SubjectsLookupService._internal();

  static final SubjectsLookupService instance =
      SubjectsLookupService._internal();

  final SahifatyApi _api = SahifatyApi();

  List<SubjectHierarchyItem>? _cachedHierarchy;
  Future<List<SubjectHierarchyItem>>? _pendingHierarchyLoad;

  Future<List<String>> resolveSubjectNames(
    Iterable<Object?> subjectKeys, {
    required String localeCode,
  }) async {
    final normalizedKeys = subjectKeys
        .map((key) => key?.toString().trim() ?? '')
        .where((key) => key.isNotEmpty)
        .toList(growable: false);

    if (normalizedKeys.isEmpty) {
      return const [];
    }

    final hierarchy = await _loadHierarchy();
    final hierarchyByKey = {
      for (final item in hierarchy) item.key: item,
    };

    final seenKeys = <String>{};
    final names = <String>[];

    for (final key in normalizedKeys) {
      if (!seenKeys.add(key)) {
        continue;
      }

      final subject = hierarchyByKey[key];
      if (subject == null) {
        continue;
      }

      final displayName = subject.displayName(localeCode);
      if (displayName.isNotEmpty) {
        names.add(displayName);
      }
    }

    return names;
  }

  Future<List<SubjectHierarchyItem>> _loadHierarchy() async {
    if (_cachedHierarchy != null) {
      return _cachedHierarchy!;
    }

    if (_pendingHierarchyLoad != null) {
      return _pendingHierarchyLoad!;
    }

    _pendingHierarchyLoad = _fetchHierarchy();

    try {
      _cachedHierarchy = await _pendingHierarchyLoad!;
      return _cachedHierarchy!;
    } finally {
      _pendingHierarchyLoad = null;
    }
  }

  Future<List<SubjectHierarchyItem>> _fetchHierarchy() async {
    final response = await _api.get('subjects');
    if (response is! http.Response || response.statusCode != 200) {
      throw Exception('Failed to load subjects hierarchy');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final rawHierarchy = decoded['hierarchy'];
    if (rawHierarchy is! List) {
      return const [];
    }

    return rawHierarchy
        .whereType<Map>()
        .map(
          (item) => SubjectHierarchyItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.key.isNotEmpty)
        .toList(growable: false);
  }
}