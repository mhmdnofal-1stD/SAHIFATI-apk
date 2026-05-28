import 'dart:convert';
import 'dart:io';

const String _defaultConfigPath = 'tool/build_config.json';
const String _defaultPubspecPath = 'pubspec.yaml';
const String _appVersionKey = 'APP_VERSION';

Future<void> main(List<String> args) async {
  final options = _GeneratorOptions.parse(args);
  final configFile = File(options.configPath);
  if (!configFile.existsSync()) {
    throw ArgumentError('Build config file not found: ${options.configPath}');
  }

  final config = _BuildConfig.fromJson(
    jsonDecode(await configFile.readAsString()) as Map<String, dynamic>,
  );
  final defines = await config.resolveDefines(
    profileName: options.profileName,
    pubspecPath: options.pubspecPath,
  );

  switch (options.format) {
    case _OutputFormat.lines:
      for (final define in defines) {
        stdout.writeln(define);
      }
      break;
    case _OutputFormat.json:
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(defines));
      break;
  }
}

enum _OutputFormat { lines, json }

class _GeneratorOptions {
  const _GeneratorOptions({
    required this.configPath,
    required this.profileName,
    required this.pubspecPath,
    required this.format,
  });

  final String configPath;
  final String profileName;
  final String pubspecPath;
  final _OutputFormat format;

  static _GeneratorOptions parse(List<String> args) {
    var configPath = _defaultConfigPath;
    var profileName = 'release';
    var pubspecPath = _defaultPubspecPath;
    var format = _OutputFormat.lines;

    for (final arg in args) {
      if (arg == '--help' || arg == '-h') {
        _printUsage();
        exit(0);
      }

      if (arg.startsWith('--config=')) {
        configPath = arg.substring('--config='.length).trim();
        continue;
      }

      if (arg.startsWith('--profile=')) {
        profileName = arg.substring('--profile='.length).trim();
        continue;
      }

      if (arg.startsWith('--pubspec=')) {
        pubspecPath = arg.substring('--pubspec='.length).trim();
        continue;
      }

      if (arg.startsWith('--format=')) {
        final raw = arg.substring('--format='.length).trim().toLowerCase();
        switch (raw) {
          case 'lines':
            format = _OutputFormat.lines;
            break;
          case 'json':
            format = _OutputFormat.json;
            break;
          default:
            throw ArgumentError(
              'Unsupported format "$raw". Expected one of: lines, json.',
            );
        }
        continue;
      }

      throw ArgumentError('Unsupported argument: $arg');
    }

    return _GeneratorOptions(
      configPath: configPath,
      profileName: profileName,
      pubspecPath: pubspecPath,
      format: format,
    );
  }

  static void _printUsage() {
    stdout.writeln(
      'Usage: dart run tool/generate_flutter_defines.dart '
      '[--config=tool/build_config.json] '
      '[--profile=release] '
      '[--pubspec=pubspec.yaml] '
      '[--format=lines|json]',
    );
  }
}

class _BuildConfig {
  const _BuildConfig({
    required this.schemaVersion,
    required this.defines,
    required this.profiles,
  });

  final int schemaVersion;
  final Map<String, String> defines;
  final Map<String, List<String>> profiles;

  factory _BuildConfig.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int || schemaVersion < 1) {
      throw const FormatException('build_config.json has an invalid schemaVersion.');
    }

    final rawDefines = json['defines'];
    if (rawDefines is! Map<String, dynamic>) {
      throw const FormatException('build_config.json is missing a defines object.');
    }

    final rawProfiles = json['profiles'];
    if (rawProfiles is! Map<String, dynamic>) {
      throw const FormatException('build_config.json is missing a profiles object.');
    }

    final defines = <String, String>{};
    for (final entry in rawDefines.entries) {
      final value = entry.value;
      if (value == null) {
        throw FormatException('Define ${entry.key} has a null value.');
      }
      final normalized = value.toString().trim();
      if (normalized.isEmpty) {
        throw FormatException('Define ${entry.key} is empty.');
      }
      defines[entry.key.trim()] = normalized;
    }

    final profiles = <String, List<String>>{};
    for (final entry in rawProfiles.entries) {
      final rawList = entry.value;
      if (rawList is! List) {
        throw FormatException('Profile ${entry.key} must be a list of define keys.');
      }

      final keys = rawList.map((item) => item.toString().trim()).toList(growable: false);
      if (keys.any((item) => item.isEmpty)) {
        throw FormatException('Profile ${entry.key} contains an empty define key.');
      }
      profiles[entry.key.trim()] = keys;
    }

    return _BuildConfig(
      schemaVersion: schemaVersion,
      defines: defines,
      profiles: profiles,
    );
  }

  Future<List<String>> resolveDefines({
    required String profileName,
    required String pubspecPath,
  }) async {
    final requestedKeys = profiles[profileName];
    if (requestedKeys == null) {
      throw ArgumentError(
        'Unknown build profile "$profileName". Available: ${profiles.keys.join(', ')}',
      );
    }

    String? appVersion;
    if (requestedKeys.contains(_appVersionKey)) {
      appVersion = await _readAppVersion(pubspecPath);
    }

    final output = <String>[];
    for (final key in requestedKeys) {
      final value = key == _appVersionKey ? appVersion : defines[key];
      if (value == null || value.trim().isEmpty) {
        throw StateError('Missing value for define $key in profile $profileName.');
      }
      output.add('--dart-define=$key=$value');
    }
    return output;
  }
}

Future<String> _readAppVersion(String pubspecPath) async {
  final pubspecFile = File(pubspecPath);
  if (!pubspecFile.existsSync()) {
    throw ArgumentError('pubspec.yaml not found: $pubspecPath');
  }

  final match = RegExp(r'^version:\s+(.+)$', multiLine: true)
      .firstMatch(await pubspecFile.readAsString());
  if (match == null) {
    throw StateError('Unable to read version from pubspec.yaml: $pubspecPath');
  }

  final version = match.group(1)?.trim();
  if (version == null || version.isEmpty) {
    throw StateError('pubspec.yaml version is empty: $pubspecPath');
  }

  final normalized = version.split('+').first.trim();
  if (normalized.isEmpty) {
    throw StateError('pubspec.yaml version is malformed: $pubspecPath');
  }

  return normalized;
}