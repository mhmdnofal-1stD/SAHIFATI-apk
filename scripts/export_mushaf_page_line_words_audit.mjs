import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');

const inputPath = path.join(
  projectRoot,
  'assets',
  'json',
  'mushaf_layout_mushaf5.json',
);
const outputJsonPath = path.join(
  projectRoot,
  'tmp',
  'mushaf-page-line-words-audit.json',
);
const outputCsvPath = path.join(
  projectRoot,
  'tmp',
  'mushaf-page-line-words-audit.csv',
);
const outputJoinedLinesCsvPath = path.join(
  projectRoot,
  'tmp',
  'mushaf-page-line-joined-text-audit.csv',
);

function toWordRecord(word, position) {
  const [surahId, ayahNo, text, marker] = word;
  return {
    position,
    surahId,
    ayahNo,
    text,
    isVerseEnd: marker === 1,
  };
}

function toPageRecord(page) {
  return {
    pageNumber: page.pageNumber,
    lines: page.lines.map((line) => ({
      lineNumber: line.lineNumber,
      wordCount: line.words.length,
      words: line.words.map((word, index) => toWordRecord(word, index + 1)),
    })),
  };
}

function escapeCsvCell(value) {
  const serialized = String(value ?? '');
  if (serialized.includes(',') || serialized.includes('"') || serialized.includes('\n')) {
    return `"${serialized.replaceAll('"', '""')}"`;
  }
  return serialized;
}

function joinLineText(line) {
  return line.words.map((word) => word.text).join(' ');
}

async function main() {
  const raw = await fs.readFile(inputPath, 'utf8');
  const payload = JSON.parse(raw);
  const pages = Array.isArray(payload?.pages) ? payload.pages : null;

  if (!pages) {
    throw new Error(`Expected a root object with a pages array in ${inputPath}`);
  }

  const auditPages = pages.map(toPageRecord);
  const csvRows = [
    ['pageNumber', 'lineNumber', 'position', 'surahId', 'ayahNo', 'isVerseEnd', 'text'],
  ];
  const joinedLinesCsvRows = [['pageNumber', 'lineNumber', 'joinedLineText']];

  for (const page of auditPages) {
    for (const line of page.lines) {
      joinedLinesCsvRows.push([
        page.pageNumber,
        line.lineNumber,
        joinLineText(line),
      ]);
      for (const word of line.words) {
        csvRows.push([
          page.pageNumber,
          line.lineNumber,
          word.position,
          word.surahId,
          word.ayahNo,
          word.isVerseEnd,
          word.text,
        ]);
      }
    }
  }

  await fs.mkdir(path.dirname(outputJsonPath), { recursive: true });
  await fs.writeFile(
    outputJsonPath,
    `${JSON.stringify(
      {
        source: path.relative(projectRoot, inputPath).replaceAll('\\', '/'),
        generatedAt: new Date().toISOString(),
        pageCount: auditPages.length,
        pages: auditPages,
      },
      null,
      2,
    )}\n`,
    'utf8',
  );
  await fs.writeFile(
    outputCsvPath,
    `${csvRows.map((row) => row.map(escapeCsvCell).join(',')).join('\n')}\n`,
    'utf8',
  );
  await fs.writeFile(
    outputJoinedLinesCsvPath,
    `${joinedLinesCsvRows
      .map((row) => row.map(escapeCsvCell).join(','))
      .join('\n')}\n`,
    'utf8',
  );

  process.stdout.write(
    JSON.stringify(
      {
        source: path.relative(projectRoot, inputPath).replaceAll('\\', '/'),
        outputJson: path.relative(projectRoot, outputJsonPath).replaceAll('\\', '/'),
        outputCsv: path.relative(projectRoot, outputCsvPath).replaceAll('\\', '/'),
        outputJoinedLinesCsv: path
          .relative(projectRoot, outputJoinedLinesCsvPath)
          .replaceAll('\\', '/'),
        pageCount: auditPages.length,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
  process.exitCode = 1;
});