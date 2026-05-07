import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const int _defaultMushafId = 5;
const int _defaultStartPage = 1;
const int _defaultEndPage = 604;
const String _defaultOutputPath = 'assets/json/mushaf_layout_mushaf5.json';

Future<void> main(List<String> args) async {
  final options = _GeneratorOptions.fromArgs(args);
  final client = http.Client();

  try {
    final pages = <Map<String, Object?>>[];
    for (var page = options.startPage; page <= options.endPage; page += 1) {
      stderr.writeln(
        'Fetching mushaf layout page $page/${options.endPage} '
        '(mushaf=${options.mushafId})...',
      );

      final payload = await _fetchPagePayload(
        client,
        mushafId: options.mushafId,
        pageNumber: page,
      );
      pages.add(_compactPagePayload(pageNumber: page, payload: payload));
    }

    final outputFile = File(options.outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(
      jsonEncode({
        'mushaf': options.mushafId,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'pages': pages,
      }),
      flush: true,
    );

    stdout.writeln(
      'Generated ${options.outputPath} '
      'for pages ${options.startPage}-${options.endPage}.',
    );
  } finally {
    client.close();
  }
}

Future<Map<String, dynamic>> _fetchPagePayload(
  http.Client client, {
  required int mushafId,
  required int pageNumber,
}) async {
  final uri = Uri.parse(
    'https://api.quran.com/api/v4/verses/by_page/$pageNumber'
    '?mushaf=$mushafId&words=true&word_fields=text_qpc_hafs,text_uthmani,line_number',
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
        throw const FormatException('Page response is not a JSON object.');
      }
      return decoded;
    } catch (error) {
      lastError = error;
      if (attempt == 3) {
        rethrow;
      }
    }
  }

  throw StateError('Failed to fetch page $pageNumber: $lastError');
}

Map<String, Object?> _compactPagePayload({
  required int pageNumber,
  required Map<String, dynamic> payload,
}) {
  final rawVerses = payload['verses'] as List<dynamic>? ?? const <dynamic>[];
  final wordsByLine = <int, List<List<Object?>>>{};

  for (final rawVerse in rawVerses) {
    if (rawVerse is! Map<String, dynamic>) {
      continue;
    }

    final verseKey = rawVerse['verse_key'] as String?;
    final ayahNo = rawVerse['verse_number'] as int?;
    if (verseKey == null || ayahNo == null) {
      continue;
    }

    final keyParts = verseKey.split(':');
    if (keyParts.length != 2) {
      continue;
    }
    final surahId = int.tryParse(keyParts.first);
    if (surahId == null) {
      continue;
    }

    final rawWords = rawVerse['words'] as List<dynamic>? ?? const <dynamic>[];
    for (final rawWord in rawWords) {
      if (rawWord is! Map<String, dynamic>) {
        continue;
      }

      final lineNumber = rawWord['line_number'] as int?;
      if (lineNumber == null) {
        continue;
      }

      final text = ((rawWord['text_qpc_hafs'] ??
                  rawWord['text_uthmani'] ??
                  rawWord['text'])
              as String?)
          ?.trim();
      if (text == null || text.isEmpty) {
        continue;
      }

      final charTypeName = rawWord['char_type_name'] as String? ?? 'word';
      (wordsByLine[lineNumber] ??= <List<Object?>>[]).add(<Object?>[
        surahId,
        ayahNo,
        text,
        charTypeName == 'end' ? 1 : 0,
      ]);
    }
  }

  final sortedLineNumbers = wordsByLine.keys.toList()..sort();
  return <String, Object?>{
    'pageNumber': pageNumber,
    'lines': sortedLineNumbers
        .map(
          (lineNumber) => <String, Object?>{
            'lineNumber': lineNumber,
            'words': wordsByLine[lineNumber]!,
          },
        )
        .toList(growable: false),
  };
}

class _GeneratorOptions {
  const _GeneratorOptions({
    required this.mushafId,
    required this.startPage,
    required this.endPage,
    required this.outputPath,
  });

  factory _GeneratorOptions.fromArgs(List<String> args) {
    var mushafId = _defaultMushafId;
    var startPage = _defaultStartPage;
    var endPage = _defaultEndPage;
    var outputPath = _defaultOutputPath;

    for (final arg in args) {
      if (arg.startsWith('--mushaf=')) {
        mushafId = int.parse(arg.substring('--mushaf='.length));
      } else if (arg.startsWith('--start-page=')) {
        startPage = int.parse(arg.substring('--start-page='.length));
      } else if (arg.startsWith('--end-page=')) {
        endPage = int.parse(arg.substring('--end-page='.length));
      } else if (arg.startsWith('--output=')) {
        outputPath = arg.substring('--output='.length);
      }
    }

    if (startPage < 1 || endPage < startPage) {
      throw ArgumentError(
        'Invalid page range: $startPage-$endPage',
      );
    }

    return _GeneratorOptions(
      mushafId: mushafId,
      startPage: startPage,
      endPage: endPage,
      outputPath: outputPath,
    );
  }

  final int mushafId;
  final int startPage;
  final int endPage;
  final String outputPath;
}