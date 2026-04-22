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
    final normalized = _normalize(name);
    if (normalized.isEmpty) {
      return null;
    }

    for (final country in countries) {
      if (_normalize(country.name) == normalized) {
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

  static String _normalize(String? value) {
    if (value == null) {
      return '';
    }

    final buffer = StringBuffer();
    for (final codeUnit in value.trim().toLowerCase().codeUnits) {
      final isAsciiLetter = codeUnit >= 97 && codeUnit <= 122;
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isArabicLetter = codeUnit >= 0x0600 && codeUnit <= 0x06FF;
      if (isAsciiLetter || isDigit || isArabicLetter) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }
}

class ProfileCountry {
  final int id;
  final String name;
  final String emoji;
  final String iso2;
  final int phoneCode;
  final List<String> cities;

  const ProfileCountry({
    required this.id,
    required this.name,
    required this.emoji,
    required this.iso2,
    required this.phoneCode,
    required this.cities,
  });

  factory ProfileCountry.fromJson(Map<String, dynamic> json) {
    return ProfileCountry(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      iso2: json['iso2'] as String? ?? '',
      phoneCode: json['phoneCode'] as int? ?? 0,
      cities: (json['cities'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
    );
  }

  String get displayName => emoji.isEmpty ? name : '$emoji $name';

  bool hasCity(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    return cities.any((city) => city.toLowerCase() == normalized.toLowerCase());
  }
}