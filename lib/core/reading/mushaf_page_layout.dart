enum MushafPageLineKind {
  words,
  surahHeader,
  basmala,
  blank,
}

class MushafWordLayout {
  const MushafWordLayout({
    required this.surahId,
    required this.ayahNo,
    required this.position,
    required this.lineNumber,
    required this.text,
    required this.charTypeName,
  });

  factory MushafWordLayout.fromJson(
    Object? json, {
    required int lineNumber,
    required int position,
  }) {
    if (json is List<dynamic>) {
      if (json.length < 4) {
        throw FormatException('Invalid compact mushaf word payload: $json');
      }

      return MushafWordLayout(
        surahId: json[0] as int,
        ayahNo: json[1] as int,
        position: position,
        lineNumber: lineNumber,
        text: json[2] as String,
        charTypeName: (json[3] as int) == 1 ? 'end' : 'word',
      );
    }

    if (json is! Map<String, dynamic>) {
      throw FormatException('Invalid mushaf word payload: $json');
    }

    return MushafWordLayout(
      surahId: json['surahId'] as int,
      ayahNo: json['ayahNo'] as int,
      position: json['position'] as int? ?? position,
      lineNumber: json['lineNumber'] as int? ?? lineNumber,
      text: json['text'] as String,
      charTypeName: json['charTypeName'] as String? ?? 'word',
    );
  }

  final int surahId;
  final int ayahNo;
  final int position;
  final int lineNumber;
  final String text;
  final String charTypeName;

  bool get isVerseStart => position == 1 && charTypeName == 'word';

  bool get isVerseEnd => charTypeName == 'end';
}

class MushafWordLine {
  const MushafWordLine({
    required this.lineNumber,
    required this.words,
  });

  factory MushafWordLine.fromJson(Map<String, dynamic> json) {
    final lineNumber = json['lineNumber'] as int;
    final rawWords = (json['words'] as List<dynamic>).toList(growable: false);
    final words = rawWords
        .asMap()
        .entries
        .map(
          (entry) => MushafWordLayout.fromJson(
            entry.value,
            lineNumber: lineNumber,
            position: entry.key + 1,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => left.position.compareTo(right.position));

    return MushafWordLine(
      lineNumber: lineNumber,
      words: words,
    );
  }

  final int lineNumber;
  final List<MushafWordLayout> words;

  MushafWordLayout? get firstWord => words.isEmpty ? null : words.first;

  bool get startsSurah {
    final first = firstWord;
    return first != null && first.ayahNo == 1 && first.isVerseStart;
  }
}

class MushafRenderableLine {
  const MushafRenderableLine._({
    required this.lineNumber,
    required this.kind,
    this.words = const <MushafWordLayout>[],
    this.surahId,
  });

  const MushafRenderableLine.words({
    required int lineNumber,
    required List<MushafWordLayout> words,
  }) : this._(
          lineNumber: lineNumber,
          kind: MushafPageLineKind.words,
          words: words,
        );

  const MushafRenderableLine.surahHeader({
    required int lineNumber,
    required int surahId,
  }) : this._(
          lineNumber: lineNumber,
          kind: MushafPageLineKind.surahHeader,
          surahId: surahId,
        );

  const MushafRenderableLine.basmala({
    required int lineNumber,
    required int surahId,
  }) : this._(
          lineNumber: lineNumber,
          kind: MushafPageLineKind.basmala,
          surahId: surahId,
        );

  const MushafRenderableLine.blank({
    required int lineNumber,
  }) : this._(
          lineNumber: lineNumber,
          kind: MushafPageLineKind.blank,
        );

  final int lineNumber;
  final MushafPageLineKind kind;
  final List<MushafWordLayout> words;
  final int? surahId;
}

class MushafPageLayout {
  const MushafPageLayout({
    required this.pageNumber,
    required this.lines,
  });

  factory MushafPageLayout.fromJson(Map<String, dynamic> json) {
    final lines = (json['lines'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MushafWordLine.fromJson)
        .toList(growable: false)
      ..sort((left, right) => left.lineNumber.compareTo(right.lineNumber));

    return MushafPageLayout(
      pageNumber: json['pageNumber'] as int,
      lines: lines,
    );
  }

  final int pageNumber;
  final List<MushafWordLine> lines;

  List<MushafRenderableLine> buildRenderableLines() {
    if (lines.isEmpty) {
      return const <MushafRenderableLine>[];
    }

    final renderable = <MushafRenderableLine>[];
    var previousLineNumber = 0;

    for (final line in lines) {
      if (line.lineNumber > previousLineNumber + 1) {
        renderable.addAll(
          _expandGap(
            startLineNumber: previousLineNumber + 1,
            endLineNumber: line.lineNumber - 1,
            nextLine: line,
          ),
        );
      }

      renderable.add(
        MushafRenderableLine.words(
          lineNumber: line.lineNumber,
          words: line.words,
        ),
      );
      previousLineNumber = line.lineNumber;
    }

    return renderable;
  }

  List<MushafRenderableLine> _expandGap({
    required int startLineNumber,
    required int endLineNumber,
    required MushafWordLine nextLine,
  }) {
    if (endLineNumber < startLineNumber) {
      return const <MushafRenderableLine>[];
    }

    if (!nextLine.startsSurah) {
      return List<MushafRenderableLine>.generate(
        endLineNumber - startLineNumber + 1,
        (index) => MushafRenderableLine.blank(
          lineNumber: startLineNumber + index,
        ),
        growable: false,
      );
    }

    final firstWord = nextLine.firstWord!;
    final surahId = firstWord.surahId;
    final gapSize = endLineNumber - startLineNumber + 1;
    final renderable = <MushafRenderableLine>[
      MushafRenderableLine.surahHeader(
        lineNumber: startLineNumber,
        surahId: surahId,
      ),
    ];

    var nextGapLine = startLineNumber + 1;
    if (surahId != 1 && surahId != 9 && gapSize >= 2) {
      renderable.add(
        MushafRenderableLine.basmala(
          lineNumber: nextGapLine,
          surahId: surahId,
        ),
      );
      nextGapLine += 1;
    }

    while (nextGapLine <= endLineNumber) {
      renderable.add(
        MushafRenderableLine.blank(lineNumber: nextGapLine),
      );
      nextGapLine += 1;
    }

    return renderable;
  }
}