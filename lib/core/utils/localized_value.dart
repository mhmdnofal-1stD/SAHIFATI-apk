String normalizeLocalizedLanguageCode(String? languageCode) {
  final normalized = (languageCode ?? '').trim().toLowerCase().replaceAll('_', '-');
  if (normalized.isEmpty) {
    return '';
  }

  return normalized.split('-').first;
}

Map<String, String> localizedStringMapFromDynamic(dynamic value) {
  if (value is! Map) {
    return const <String, String>{};
  }

  final localized = <String, String>{};
  for (final entry in value.entries) {
    final key = normalizeLocalizedLanguageCode(entry.key?.toString());
    final text = entry.value?.toString().trim() ?? '';
    if (key.isEmpty || text.isEmpty) {
      continue;
    }

    localized[key] = text;
  }

  return localized;
}

String localizedValue(
  Map<String, String>? values, {
  String? preferredLocale,
  String? fallbackLocale,
}) {
  if (values == null || values.isEmpty) {
    return '';
  }

  final normalizedPreferred = normalizeLocalizedLanguageCode(preferredLocale);
  if (normalizedPreferred.isNotEmpty) {
    final preferred = values[normalizedPreferred]?.trim() ?? '';
    if (preferred.isNotEmpty) {
      return preferred;
    }
  }

  final normalizedFallback = normalizeLocalizedLanguageCode(fallbackLocale);
  if (normalizedFallback.isNotEmpty) {
    final fallback = values[normalizedFallback]?.trim() ?? '';
    if (fallback.isNotEmpty) {
      return fallback;
    }
  }

  final arabic = values['ar']?.trim() ?? '';
  if (arabic.isNotEmpty) {
    return arabic;
  }

  for (final value in values.values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }

  return '';
}