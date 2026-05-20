String _normalizeLocationValue(String? value) {
  if (value == null) {
    return '';
  }

  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }

  final buffer = StringBuffer();
  for (final codeUnit in normalized.runes) {
    final isAsciiLetter = codeUnit >= 97 && codeUnit <= 122;
    final isDigit = codeUnit >= 48 && codeUnit <= 57;
    final isArabicLetter = codeUnit >= 0x0600 && codeUnit <= 0x06FF;
    final isLatinExtended = codeUnit >= 0x00C0 && codeUnit <= 0x024F;
    final isCyrillic = codeUnit >= 0x0400 && codeUnit <= 0x04FF;
    final isGreek = codeUnit >= 0x0370 && codeUnit <= 0x03FF;
    final isHebrew = codeUnit >= 0x0590 && codeUnit <= 0x05FF;
    final isDevanagari = codeUnit >= 0x0900 && codeUnit <= 0x097F;
    final isBengali = codeUnit >= 0x0980 && codeUnit <= 0x09FF;
    final isGurmukhi = codeUnit >= 0x0A00 && codeUnit <= 0x0A7F;
    final isGujarati = codeUnit >= 0x0A80 && codeUnit <= 0x0AFF;
    final isTamil = codeUnit >= 0x0B80 && codeUnit <= 0x0BFF;
    final isKannada = codeUnit >= 0x0C80 && codeUnit <= 0x0CFF;
    final isThai = codeUnit >= 0x0E00 && codeUnit <= 0x0E7F;
    final isGeorgian = codeUnit >= 0x10A0 && codeUnit <= 0x10FF;
    final isEthiopic = codeUnit >= 0x1200 && codeUnit <= 0x137F;
    final isCjk = codeUnit >= 0x4E00 && codeUnit <= 0x9FFF;
    final isHangul = codeUnit >= 0xAC00 && codeUnit <= 0xD7AF;
    final isKana = codeUnit >= 0x3040 && codeUnit <= 0x30FF;

    if (
        isAsciiLetter ||
        isDigit ||
        isArabicLetter ||
        isLatinExtended ||
        isCyrillic ||
        isGreek ||
        isHebrew ||
        isDevanagari ||
        isBengali ||
        isGurmukhi ||
        isGujarati ||
        isTamil ||
        isKannada ||
        isThai ||
        isGeorgian ||
        isEthiopic ||
        isCjk ||
        isHangul ||
        isKana) {
      buffer.writeCharCode(codeUnit);
    }
  }

  return buffer.toString();
}

const String _restrictedRegionIso2 = 'TW';
const String _restrictedRegionDisplayName = 'China/Taiwan, China';

class ProfileLocationLookup {
  final String source;
  final int countryCount;
  final List<String> excludedCountries;
  final List<ProfileCountry> countries;

  const ProfileLocationLookup({
    required this.source,
    required this.countryCount,
    required this.excludedCountries,
    required this.countries,
  });

  factory ProfileLocationLookup.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    final rawCountries = json['countries'] as List<dynamic>? ?? const [];

    return ProfileLocationLookup(
      source: metadata['source'] as String? ?? '',
      countryCount: metadata['countryCount'] as int? ?? rawCountries.length,
      excludedCountries: (metadata['excludedCountries'] as List<dynamic>? ??
              const [])
          .map((item) => '$item')
          .toList(),
      countries: rawCountries
          .map((item) =>
              ProfileCountry.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  ProfileCountry? findByName(String? name) {
    final normalized = _normalizeLocationValue(name);
    if (normalized.isEmpty) {
      return null;
    }

    for (final country in countries) {
      if (country.matchesName(normalized)) {
        return country;
      }
    }

    return null;
  }

  ProfileCountry? findByPhoneCode(int? phoneCode) {
    if (phoneCode == null) {
      return null;
    }

    for (final country in countries) {
      if (country.phoneCode == phoneCode) {
        return country;
      }
    }

    return null;
  }
}

class ProfileCity {
  final String value;
  final String displayName;

  const ProfileCity({
    required this.value,
    required this.displayName,
  });

  factory ProfileCity.fromJson(dynamic json) {
    if (json is String) {
      return ProfileCity(value: json, displayName: json);
    }

    final map = Map<String, dynamic>.from(json as Map);
    final value = (map['value'] as String?) ?? (map['name'] as String?) ?? '';
    final displayName =
        (map['displayName'] as String?) ?? (map['label'] as String?) ?? value;

    return ProfileCity(
      value: value,
      displayName: displayName,
    );
  }

  String get effectiveDisplayName =>
      displayName.trim().isEmpty ? value : displayName;

  bool matchesValue(String? candidate) {
    final normalizedCandidate = _normalizeLocationValue(candidate);
    if (normalizedCandidate.isEmpty) {
      return false;
    }

    return _normalizeLocationValue(value) == normalizedCandidate ||
        _normalizeLocationValue(displayName) == normalizedCandidate;
  }
}

class ProfileCountry {
  final int id;
  final String name;
  final String nativeName;
  final String emoji;
  final String iso2;
  final int phoneCode;
  final List<String> languages;
  final List<ProfileCity> cities;

  const ProfileCountry({
    required this.id,
    required this.name,
    required this.nativeName,
    required this.emoji,
    required this.iso2,
    required this.phoneCode,
    required this.languages,
    required this.cities,
  });

  factory ProfileCountry.fromJson(Map<String, dynamic> json) {
    return ProfileCountry(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      nativeName:
          (json['nativeName'] as String?) ?? (json['displayName'] as String?) ?? '',
      emoji: json['emoji'] as String? ?? '',
      iso2: json['iso2'] as String? ?? '',
      phoneCode: json['phoneCode'] as int? ?? 0,
      languages: (json['languages'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      cities: (json['cities'] as List<dynamic>? ?? const [])
          .map(ProfileCity.fromJson)
          .toList(),
    );
  }

  String get localizedName =>
      iso2.toUpperCase() == _restrictedRegionIso2
          ? _restrictedRegionDisplayName
          : (nativeName.trim().isEmpty ? name : nativeName.trim());

    String get displayName => localizedName;

  bool matchesName(String? candidate) {
    final normalizedCandidate = _normalizeLocationValue(candidate);
    if (normalizedCandidate.isEmpty) {
      return false;
    }

    return _normalizeLocationValue(name) == normalizedCandidate ||
        _normalizeLocationValue(nativeName) == normalizedCandidate ||
        _normalizeLocationValue(_restrictedRegionDisplayName) ==
            normalizedCandidate;
  }

  ProfileCity? findCity(String? value) {
    for (final city in cities) {
      if (city.matchesValue(value)) {
        return city;
      }
    }
    return null;
  }

  bool hasCity(String? value) {
    return findCity(value) != null;
  }
}