const fs = require('fs');
const path = require('path');

const QURAN_JSON_PATH = path.join('E:', 'Sahifati', 'sahifati.org', 'assets', 'json', 'quran.json');
const ASSET_TRANSLATIONS_DIR = path.join('E:', 'Sahifati', 'sahifati_app', 'sahifati_app_v01', 'assets', 'json', 'ayah_translations');
const DART_TRANSLATIONS_DIR = path.join('C:', 'Users', 'DELL', 'AppData', 'Local', 'Pub', 'Cache', 'hosted', 'pub.dev', 'quran-1.3.1', 'lib', 'translations');
const OUTPUT_PATH = path.join('E:', 'Sahifati', 'sahifati_app', 'sahifati_app_v01', 'assets', 'json', 'ayah_translations_all.json');

const DART_FILES = {
  en: { file: 'en_saheeh.dart', translationKey: 'en_saheeh', description: 'English - Saheeh International translation' },
  tr: { file: 'tr_saheeh.dart', translationKey: 'tr_saheeh', description: 'Turkish - Saheeh translation' },
  ml: { file: 'ml_abdulhameed.dart', translationKey: 'ml_abdulhameed', description: 'Malayalam - Abdul Hameed translation' },
  fa: { file: 'fa_husseindari.dart', translationKey: 'fa_husseinDari', description: 'Persian - Hussein Dari translation' },
  fr: { file: 'fr_hamidullah.dart', translationKey: 'fr_hamidullah', description: 'French - Hamidullah translation' },
  it: { file: 'it_piccardo.dart', translationKey: 'it_piccardo', description: 'Italian - Piccardo translation' },
  nl: { file: 'nl_siregar.dart', translationKey: 'nl_siregar', description: 'Dutch - Siregar translation' },
  pt: { file: 'portuguese.dart', translationKey: 'portuguese', description: 'Portuguese translation' },
  ru: { file: 'ru_kuliev.dart', translationKey: 'ru_kuliev', description: 'Russian - Kuliev translation' },
  ur: { file: 'urdu.dart', translationKey: 'urdu', description: 'Urdu translation' },
  bn: { file: 'bengali.dart', translationKey: 'bengali', description: 'Bengali translation' },
  zh: { file: 'chinese.dart', translationKey: 'chinese', description: 'Chinese translation' },
  id: { file: 'indonesian.dart', translationKey: 'indonesian', description: 'Indonesian translation' },
  es: { file: 'spanish.dart', translationKey: 'spanish', description: 'Spanish translation' },
  sv: { file: 'swedish.dart', translationKey: 'swedish', description: 'Swedish translation' },
};

const ASSET_FILES = {
  de: { translationKey: 'german_bubenheim', description: 'German - Bubenheim translation (QuranEnc)' },
  hi: { translationKey: 'hindi_omari', description: 'Hindi - Omari translation (QuranEnc)' },
  ms: { translationKey: 'malay_basumayyah', description: 'Malay - Basumayyah translation (QuranEnc)' },
  pa: { translationKey: 'punjabi_arif', description: 'Punjabi - Arif translation (QuranEnc)' },
  ha: { translationKey: 'hausa_gummi', description: 'Hausa - Gummi translation (QuranEnc)' },
  sw: { translationKey: 'swahili_rwwad', description: 'Swahili - Rwwad translation (QuranEnc)' },
};

function parseDartFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const bracketStart = content.indexOf('[');
  const bracketEnd = content.lastIndexOf(']');
  const arrayContent = content.substring(bracketStart + 1, bracketEnd);

  const entryRegex = /\{\s*"surah_number"\s*:\s*(\d+)\s*,\s*"verse_number"\s*:\s*(\d+)\s*,\s*"content"\s*:\s*"/g;

  const results = [];
  let match;

  while ((match = entryRegex.exec(arrayContent)) !== null) {
    const surahNumber = parseInt(match[1]);
    const verseNumber = parseInt(match[2]);
    const contentStartIdx = match.index + match[0].length - 1;

    let text = '';
    let idx = contentStartIdx + 1;
    let escaped = false;
    let done = false;

    while (idx < arrayContent.length && !done) {
      const ch = arrayContent[idx];
      if (escaped) {
        switch (ch) {
          case 'n': text += '\n'; break;
          case 'r': text += '\r'; break;
          case 't': text += '\t'; break;
          default: text += ch; break;
        }
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === '"') {
        done = true;
      } else if (ch === '\n' || ch === '\r') {
        idx++;
        continue;
      } else {
        text += ch;
      }
      idx++;
    }

    results.push({
      surah_number: surahNumber,
      verse_number: verseNumber,
      content: text,
    });

    entryRegex.lastIndex = idx;
  }

  return results;
}

console.log('Loading quran.json for mapping...');
const quranData = JSON.parse(fs.readFileSync(QURAN_JSON_PATH, 'utf8'));

const surahVerseToAyaId = new Map();
const ayaIdToArabic = new Map();

for (const ayah of quranData.data) {
  const key = `${ayah.surah.id}:${ayah.ayahNo}`;
  surahVerseToAyaId.set(key, ayah._id);
  ayaIdToArabic.set(ayah._id, ayah.text);
}

console.log(`Built mapping for ${surahVerseToAyaId.size} ayat from quran.json`);

const ayatMap = new Map();

for (let i = 1; i <= 6236; i++) {
  ayatMap.set(i, { aya_id: i, ar: ayaIdToArabic.get(i) || '' });
}

console.log('Processing Dart translation files...');
for (const [langCode, info] of Object.entries(DART_FILES)) {
  const filePath = path.join(DART_TRANSLATIONS_DIR, info.file);
  console.log(`  Processing ${info.file}...`);
    const entries = parseDartFile(filePath);
  let count = 0;
  for (const entry of entries) {
    const key = `${entry.surah_number}:${entry.verse_number}`;
    const ayaId = surahVerseToAyaId.get(key);
    if (ayaId !== undefined) {
      ayatMap.get(ayaId)[langCode] = entry.content;
      count++;
    } else {
      console.warn(`  WARNING: No aya_id for surah ${entry.surah_number} verse ${entry.verse_number}`);
    }
  }
  console.log(`    Mapped ${count} entries for ${langCode}`);
}

console.log('Processing asset translation files...');
for (const [langCode, info] of Object.entries(ASSET_FILES)) {
  const filePath = path.join(ASSET_TRANSLATIONS_DIR, `${langCode}.json`);
  console.log(`  Processing ${langCode}.json...`);
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  let count = 0;
  for (const [surahId, ayat] of data.surahs) {
    for (let i = 0; i < ayat.length; i++) {
      const key = `${surahId}:${i + 1}`;
      const ayaId = surahVerseToAyaId.get(key);
      if (ayaId !== undefined) {
        ayatMap.get(ayaId)[langCode] = ayat[i];
        count++;
      } else {
        console.warn(`  WARNING: No aya_id for surah ${surahId} verse ${i + 1}`);
      }
    }
  }
  console.log(`    Mapped ${count} entries for ${langCode}`);
}

const ayat = Array.from(ayatMap.values()).sort((a, b) => a.aya_id - b.aya_id);

const sources = {
  ar: {
    provider: 'quran_package',
    translationKey: 'quran_text',
    description: 'Arabic Quran text (Uthmanic with diacritics) from quran package',
  },
};

for (const [langCode, info] of Object.entries(DART_FILES)) {
  sources[langCode] = {
    provider: 'quran_package',
    translationKey: info.translationKey,
    description: info.description,
  };
}

for (const [langCode, info] of Object.entries(ASSET_FILES)) {
  sources[langCode] = {
    provider: 'quranenc',
    translationKey: info.translationKey,
    description: info.description,
  };
}

const output = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  description: 'Merged ayah translations from all sources - Arabic text + 21 language translations',
  totalAyat: ayat.length,
  sources,
  ayat,
};

const outputDir = path.dirname(OUTPUT_PATH);
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

console.log(`Writing output to ${OUTPUT_PATH}...`);
fs.writeFileSync(OUTPUT_PATH, JSON.stringify(output), 'utf8');

const fileSizeMB = (fs.statSync(OUTPUT_PATH).size / (1024 * 1024)).toFixed(2);
console.log(`Done! Written ${ayat.length} ayat to ${OUTPUT_PATH} (${fileSizeMB} MB)`);