import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String _defaultRegistryPath = 'tool/ayah_translation_registry.json';
const String _defaultOutputDir = 'assets/json/ayah_translations';
const String _defaultManifestName = 'manifest.json';
const int _expectedSurahCount = 114;
const int _expectedAyahCount = 6236;

Future<void> main(List<String> args) async {
  final options = _GeneratorOptions.fromArgs(args);
  final registryFile = File(options.registryPath);
  if (!registryFile.existsSync()) {
    throw ArgumentError('Registry file not found: ${options.registryPath}');
  }

  final registry = _Registry.fromJson(
    jsonDecode(await registryFile.readAsString()) as Map<String, dynamic>,
  );

  final selectedSources = registry.sources.where((source) {
    if (!source.isApproved) {
      return false;
    }
    if (options.languageCodes.isEmpty) {
      return true;
    }
    return options.languageCodes.contains(source.languageCode);
  }).toList(growable: false);

  if (selectedSources.isEmpty) {
    throw StateError('No approved ayah translation sources matched the request.');
  }

  final client = http.Client();
  final outputDirectory = Directory(options.outputDir);
  await outputDirectory.create(recursive: true);

  try {
    final generatedAt = DateTime.now().toUtc().toIso8601String();
    final manifestEntries = <Map<String, Object?>>[];

    for (final source in selectedSources) {
      stderr.writeln(
        'Generating offline ayah bundle for ${source.languageCode} '
        '(${source.translationKey})...',
      );

      final bundle = await _fetchBundle(
        client: client,
        source: source,
        generatedAt: generatedAt,
        defaultFallbackLanguage: registry.defaultFallbackLanguage,
      );

      final outputPath = '${options.outputDir}/${source.languageCode}.json';
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(jsonEncode(bundle), flush: true);

      manifestEntries.add(<String, Object?>{
        'languageCode': source.languageCode,
        'provider': source.provider,
        'translationKey': source.translationKey,
        'path': outputPath.replaceAll('\\', '/'),
        'surahs': source.expectedSurahCount,
        'ayat': source.expectedAyahCount,
      });

      stdout.writeln('Wrote $outputPath');
    }

    final manifestFile = File('${options.outputDir}/$_defaultManifestName');
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schemaVersion': 1,
        'registryVersion': registry.version,
        'generatedAt': generatedAt,
        'defaultFallbackLanguage': registry.defaultFallbackLanguage,
        'policy': registry.policy,
        'languages': manifestEntries,
      }),
      flush: true,
    );

    stdout.writeln('Wrote ${manifestFile.path.replaceAll('\\', '/')}');
  } finally {
    client.close();
  }
}

Future<Map<String, Object?>> _fetchBundle({
  required http.Client client,
  required _RegistrySource source,
  required String generatedAt,
  required String defaultFallbackLanguage,
}) async {
  final surahs = <List<Object?>>[];
  var totalAyat = 0;

  for (var surahId = 1; surahId <= _expectedSurahCount; surahId += 1) {
    stderr.writeln(
      'Fetching ${source.languageCode} surah $surahId/$_expectedSurahCount...',
    );

    final ayat = await _fetchSuraAyat(
      client,
      translationKey: source.translationKey!,
      surahId: surahId,
    );

    totalAyat += ayat.length;
    surahs.add(<Object?>[surahId, ayat]);
  }

  final expectedAyahCount = source.expectedAyahCount;
  final expectedSurahCount = source.expectedSurahCount;
  if (surahs.length != expectedSurahCount || totalAyat != expectedAyahCount) {
    throw StateError(
      'Unexpected coverage for ${source.languageCode}: '
      '${surahs.length}/$expectedSurahCount surahs, '
      '$totalAyat/$expectedAyahCount ayat.',
    );
  }

  return <String, Object?>{
    'schemaVersion': 1,
    'generatedAt': generatedAt,
    'languageCode': source.languageCode,
    'provider': source.provider,
    'translationKey': source.translationKey,
    'defaultFallbackLanguage': defaultFallbackLanguage,
    'surahs': surahs,
  };
}

Future<List<String>> _fetchSuraAyat(
  http.Client client, {
  required String translationKey,
  required int surahId,
}) async {
  final uri = Uri.parse(
    'https://quranenc.com/api/v1/translation/sura/$translationKey/$surahId',
  );

  Object? lastError;
  for (var attempt = 1; attempt <= 3; attempt += 1) {
    try {
      final response = await client.get(uri);
      if (response.statusCode != 200) {
        throw HttpException(
          'Unexpected status ${response.statusCode} for $uri',
          uri: uri,
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Sura translation response is not an object.');
      }

      final rawResult = decoded['result'];
      if (rawResult is! List) {
        throw const FormatException('Sura translation response has no result list.');
      }

      final indexedAyat = <int, String>{};
      for (final rawAyah in rawResult) {
        if (rawAyah is! Map<String, dynamic>) {
          continue;
        }

        final rawAya = rawAyah['aya'];
        final aya = rawAya is int ? rawAya : int.tryParse('$rawAya');
        final translation = rawAyah['translation'] as String?;
        if (aya == null || translation == null) {
          continue;
        }

        indexedAyat[aya] = _normalizeTranslation(translation);
      }

      if (indexedAyat.isEmpty) {
        throw StateError('No ayat returned for $translationKey surah $surahId.');
      }

      final lastAyah = indexedAyat.keys.reduce((left, right) => left > right ? left : right);
      final ayat = <String>[];
      for (var aya = 1; aya <= lastAyah; aya += 1) {
        final translation = indexedAyat[aya];
        if (translation == null) {
          throw StateError(
            'Missing aya $aya for $translationKey surah $surahId.',
          );
        }
        ayat.add(translation);
      }

      return ayat;
    } catch (error) {
      lastError = error;
      if (attempt == 3) {
        rethrow;
      }
    }
  }

  throw StateError(
    'Failed to fetch surah $surahId for $translationKey: $lastError',
  );
}

String _normalizeTranslation(String value) {
  return value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u00A0', ' ')
      .trim();
}

class _GeneratorOptions {
  const _GeneratorOptions({
    required this.registryPath,
    required this.outputDir,
    required this.languageCodes,
  });

  factory _GeneratorOptions.fromArgs(List<String> args) {
    var registryPath = _defaultRegistryPath;
    var outputDir = _defaultOutputDir;
    final languageCodes = <String>{};

    for (final arg in args) {
      if (arg.startsWith('--registry=')) {
        registryPath = arg.substring('--registry='.length);
      } else if (arg.startsWith('--output-dir=')) {
        outputDir = arg.substring('--output-dir='.length);
      } else if (arg.startsWith('--languages=')) {
        final rawCodes = arg.substring('--languages='.length);
        for (final rawCode in rawCodes.split(',')) {
          final normalized = rawCode.trim().toLowerCase();
          if (normalized.isNotEmpty) {
            languageCodes.add(normalized);
          }
        }
      }
    }

    return _GeneratorOptions(
      registryPath: registryPath,
      outputDir: outputDir,
      languageCodes: languageCodes,
    );
  }

  final String registryPath;
  final String outputDir;
  final Set<String> languageCodes;
}

class _Registry {
  const _Registry({
    required this.version,
    required this.defaultFallbackLanguage,
    required this.policy,
    required this.sources,
  });

  factory _Registry.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'] as List<dynamic>? ?? const <dynamic>[];
    return _Registry(
      version: json['version'] as int? ?? 1,
      defaultFallbackLanguage:
          json['defaultFallbackLanguage'] as String? ?? 'ar',
      policy: json['policy'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      sources: rawSources
          .whereType<Map<String, dynamic>>()
          .map(_RegistrySource.fromJson)
          .toList(growable: false),
    );
  }

  final int version;
  final String defaultFallbackLanguage;
  final Map<String, dynamic> policy;
  final List<_RegistrySource> sources;
}

class _RegistrySource {
  const _RegistrySource({
    required this.languageCode,
    required this.status,
    required this.provider,
    required this.translationKey,
    required this.expectedSurahCount,
    required this.expectedAyahCount,
  });

  factory _RegistrySource.fromJson(Map<String, dynamic> json) {
    final verifiedCoverage = json['verifiedCoverage'] as Map<String, dynamic>?;
    return _RegistrySource(
      languageCode: (json['languageCode'] as String? ?? '').trim().toLowerCase(),
      status: (json['status'] as String? ?? '').trim().toLowerCase(),
      provider: json['provider'] as String?,
      translationKey: json['translationKey'] as String?,
      expectedSurahCount:
          verifiedCoverage?['surahs'] as int? ?? _expectedSurahCount,
      expectedAyahCount:
          verifiedCoverage?['ayat'] as int? ?? _expectedAyahCount,
    );
  }

  final String languageCode;
  final String status;
  final String? provider;
  final String? translationKey;
  final int expectedSurahCount;
  final int expectedAyahCount;

  bool get isApproved =>
      status == 'approved' &&
      provider == 'quranenc' &&
      translationKey != null &&
      translationKey!.isNotEmpty;
}