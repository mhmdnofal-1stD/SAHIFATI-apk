import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/core/reading/mushaf_page_layout.dart';

void main() {
  test('buildRenderableLines inserts surah header and basmala before surah start', () {
    final layout = MushafPageLayout.fromJson({
      'pageNumber': 2,
      'lines': [
        {
          'lineNumber': 3,
          'words': [
            {
              'surahId': 2,
              'ayahNo': 1,
              'position': 1,
              'lineNumber': 3,
              'text': 'الٓمٓ',
              'charTypeName': 'word',
            },
          ],
        },
        {
          'lineNumber': 4,
          'words': [
            {
              'surahId': 2,
              'ayahNo': 2,
              'position': 1,
              'lineNumber': 4,
              'text': 'لِّلْمُتَّقِينَ',
              'charTypeName': 'word',
            },
          ],
        },
      ],
    });

    final renderable = layout.buildRenderableLines();

    expect(
      renderable.map((line) => line.kind).toList(growable: false),
      <MushafPageLineKind>[
        MushafPageLineKind.surahHeader,
        MushafPageLineKind.basmala,
        MushafPageLineKind.words,
        MushafPageLineKind.words,
      ],
    );
    expect(
      renderable.map((line) => line.lineNumber).toList(growable: false),
      <int>[1, 2, 3, 4],
    );
    expect(renderable.first.surahId, 2);
    expect(renderable[1].surahId, 2);
  });

  test('buildRenderableLines inserts only surah header for surah nine start', () {
    final layout = MushafPageLayout.fromJson({
      'pageNumber': 187,
      'lines': [
        {
          'lineNumber': 2,
          'words': [
            {
              'surahId': 9,
              'ayahNo': 1,
              'position': 1,
              'lineNumber': 2,
              'text': 'بَرَآءَةٌۭ',
              'charTypeName': 'word',
            },
          ],
        },
      ],
    });

    final renderable = layout.buildRenderableLines();

    expect(renderable.length, 2);
    expect(renderable.first.kind, MushafPageLineKind.surahHeader);
    expect(renderable.first.lineNumber, 1);
    expect(renderable.last.kind, MushafPageLineKind.words);
    expect(renderable.last.lineNumber, 2);
  });

  test('fromJson decodes compact generated word arrays', () {
    final layout = MushafPageLayout.fromJson({
      'pageNumber': 1,
      'lines': [
        {
          'lineNumber': 2,
          'words': [
            [1, 1, 'بِسۡمِ', 0],
            [1, 1, 'ٱللَّهِ', 0],
            [1, 1, '١', 1],
          ],
        },
      ],
    });

    expect(layout.lines, hasLength(1));
    expect(layout.lines.first.words, hasLength(3));
    expect(layout.lines.first.words.first.text, 'بِسۡمِ');
    expect(layout.lines.first.words.last.isVerseEnd, isTrue);
    expect(layout.lines.first.words.last.position, 3);
  });

  test('buildRenderableLines preserves non-surah gaps as blank lines', () {
    final layout = MushafPageLayout.fromJson({
      'pageNumber': 10,
      'lines': [
        {
          'lineNumber': 1,
          'words': [
            {
              'surahId': 2,
              'ayahNo': 70,
              'position': 3,
              'lineNumber': 1,
              'text': 'قَالُوا۟',
              'charTypeName': 'word',
            },
          ],
        },
        {
          'lineNumber': 3,
          'words': [
            {
              'surahId': 2,
              'ayahNo': 70,
              'position': 4,
              'lineNumber': 3,
              'text': 'ٱدْعُ',
              'charTypeName': 'word',
            },
          ],
        },
      ],
    });

    final renderable = layout.buildRenderableLines();

    expect(renderable.length, 3);
    expect(renderable[1].kind, MushafPageLineKind.blank);
    expect(renderable[1].lineNumber, 2);
  });
}