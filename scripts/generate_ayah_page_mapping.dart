import 'dart:convert';
import 'dart:io';

import 'package:quran/quran.dart' as quran;

Future<void> main(List<String> args) async {
  final scriptDir = File.fromUri(Platform.script).parent;
  final projectRoot = scriptDir.parent;
  final inputPath = args.isNotEmpty
      ? args[0]
      : '${projectRoot.path}${Platform.pathSeparator}assets${Platform.pathSeparator}json${Platform.pathSeparator}data.json';
  final outputPath = args.length > 1
      ? args[1]
      : '${projectRoot.path}${Platform.pathSeparator}tmp${Platform.pathSeparator}ayah-page-mapping-canonical.json';

  final sourceFile = File(inputPath);
  if (!await sourceFile.exists()) {
    stderr.writeln('Input file not found: $inputPath');
    exitCode = 1;
    return;
  }

  final raw = await sourceFile.readAsString();
  final payload = jsonDecode(raw);
  final rows = payload is List
      ? payload
      : payload is Map && payload['data'] is List
          ? payload['data'] as List
          : null;
  if (rows == null) {
    stderr.writeln('Expected a JSON array in $inputPath');
    exitCode = 1;
    return;
  }

  final mapping = <Map<String, int>>[];
  var mismatches = 0;

  for (final entry in rows) {
    if (entry is! Map) {
      continue;
    }

    final ayah = Map<String, dynamic>.from(entry.cast<String, dynamic>());
    final ayahId = (ayah['_id'] as num?)?.toInt();
    final ayahNo = (ayah['ayahNo'] as num?)?.toInt();
    final surah = ayah['surah'];
    final surahId = surah is Map ? (surah['id'] as num?)?.toInt() : null;

    if (ayahId == null || ayahNo == null || surahId == null) {
      continue;
    }

    final canonicalPage = quran.getPageNumber(surahId, ayahNo);
    final currentPage = (ayah['page'] as num?)?.toInt();
    if (currentPage != canonicalPage) {
      mismatches += 1;
    }

    mapping.add({
      '_id': ayahId,
      'page': canonicalPage,
    });
  }

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(mapping),
  );

  stdout.writeln('Generated ${mapping.length} canonical ayah/page pairs');
  stdout.writeln('Mismatches vs source data.json: $mismatches');
  stdout.writeln('Output: ${outputFile.path}');
}