import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const defaultLookupPath = path.join(rootDir, 'assets', 'json', 'profile_location_lookup.json');
const cityDisplayOverrides = new Map([
  ['JO:alkarak', 'الكرك'],
]);

function readArg(name) {
  const prefix = `${name}=`;
  const match = process.argv.find((arg) => arg.startsWith(prefix));
  return match ? match.slice(prefix.length) : null;
}

function normalizeLookupValue(value) {
  return String(value ?? '')
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, '');
}

function hasNonLatinCharacters(value) {
  return /[^\u0000-\u024f\s\-'.]/u.test(String(value ?? ''));
}

function detectPrimaryScript(value) {
  const text = String(value ?? '');

  if (/[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]/u.test(text)) {
    return 'arabic';
  }
  if (/[\u0400-\u04ff]/u.test(text)) {
    return 'cyrillic';
  }
  if (/[\u0370-\u03ff]/u.test(text)) {
    return 'greek';
  }
  if (/[\u0590-\u05ff]/u.test(text)) {
    return 'hebrew';
  }
  if (/[\u0900-\u097f]/u.test(text)) {
    return 'devanagari';
  }
  if (/[\u4e00-\u9fff]/u.test(text)) {
    return 'han';
  }
  if (/[\u3040-\u30ff]/u.test(text)) {
    return 'kana';
  }
  if (/[\uac00-\ud7af]/u.test(text)) {
    return 'hangul';
  }
  if (/[\u0e00-\u0e7f]/u.test(text)) {
    return 'thai';
  }
  if (/[\u10a0-\u10ff]/u.test(text)) {
    return 'georgian';
  }
  if (/[\u0530-\u058f]/u.test(text)) {
    return 'armenian';
  }

  return hasNonLatinCharacters(text) ? 'other' : 'latin';
}

function getCityOverride(countryIso2, cityValue) {
  const key = `${String(countryIso2 ?? '').trim().toUpperCase()}:${normalizeLookupValue(cityValue)}`;
  return cityDisplayOverrides.get(key) ?? null;
}

function currentLocalDate() {
  const now = new Date();
  const year = String(now.getFullYear());
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function toCityRecord(city) {
  if (typeof city == 'string') {
    return {
      value: city,
      displayName: city,
    };
  }

  return {
    value: String(city?.value ?? city?.name ?? ''),
    displayName: String(city?.displayName ?? city?.value ?? city?.name ?? ''),
  };
}

function featureCodeScore(featureCode) {
  if (featureCode == 'PPLC') {
    return 40;
  }
  if (featureCode == 'PPLA') {
    return 35;
  }
  if (featureCode == 'PPLA2') {
    return 30;
  }
  if (featureCode == 'PPLA3') {
    return 25;
  }
  if (featureCode == 'PPLA4') {
    return 20;
  }
  if (featureCode == 'PPLG') {
    return 15;
  }
  if (featureCode == 'PPL') {
    return 10;
  }
  return 0;
}

function candidateScore(matchType, featureCode, population) {
  let score = featureCodeScore(featureCode);
  if (matchType == 'name') {
    score += 200;
  } else if (matchType == 'ascii') {
    score += 170;
  } else if (matchType == 'alternate') {
    score += 140;
  }

  const numericPopulation = Number.parseInt(String(population ?? '0'), 10);
  if (Number.isFinite(numericPopulation) && numericPopulation > 0) {
    score += Math.min(60, Math.floor(Math.log10(numericPopulation) * 10));
  }

  return score;
}

function buildPreferredLanguages(countryName, nativeName, languages) {
  const ordered = [];
  const seen = new Set();

  for (const language of languages ?? []) {
    const normalized = String(language ?? '').trim().toLowerCase();
    if (!normalized || seen.has(normalized)) {
      continue;
    }
    seen.add(normalized);
    ordered.push(normalized);
  }

  if (ordered.length <= 1) {
    return ordered;
  }

  if (normalizeLookupValue(countryName) == normalizeLookupValue(nativeName)) {
    return ordered;
  }

  return [
    ...ordered.filter((language) => language != 'en'),
    ...ordered.filter((language) => language == 'en'),
  ];
}

function chooseBestAlternateName(candidates, canonicalName) {
  if (candidates == null || candidates.length == 0) {
    return null;
  }

  const usable = candidates
      .filter((candidate) => !candidate.isHistoric && !candidate.isColloquial)
      .sort((left, right) => {
        if (left.isPreferred != right.isPreferred) {
          return left.isPreferred ? -1 : 1;
        }
        if (left.isShort != right.isShort) {
          return left.isShort ? 1 : -1;
        }
        if (
          normalizeLookupValue(left.name) == normalizeLookupValue(canonicalName) &&
          normalizeLookupValue(right.name) != normalizeLookupValue(canonicalName)
        ) {
          return 1;
        }
        if (
          normalizeLookupValue(left.name) != normalizeLookupValue(canonicalName) &&
          normalizeLookupValue(right.name) == normalizeLookupValue(canonicalName)
        ) {
          return -1;
        }
        return left.name.length - right.name.length;
      });

  return usable[0] ?? null;
}

function selectCityDisplayName(countryIso2, city, countryName, nativeCountryName, languages, cityMatch, altNamesByGeonameId) {
  const override = getCityOverride(countryIso2, city.value);
  if (override != null) {
    return override;
  }

  if (cityMatch == null) {
    return city.displayName || city.value;
  }

  const preferredLanguages = buildPreferredLanguages(
    countryName,
    nativeCountryName,
    languages,
  );
  const alternateNames = altNamesByGeonameId.get(cityMatch.geonameId);

  for (const language of preferredLanguages) {
    const variants = [language, language.split('-')[0]].filter(Boolean);
    for (const variant of variants) {
      const chosen = chooseBestAlternateName(
        alternateNames?.get(variant),
        city.value,
      );
      if (chosen != null && chosen.name.trim().length > 0) {
        return chosen.name.trim();
      }
    }
  }

  const preferredScript = detectPrimaryScript(nativeCountryName);
  if (preferredScript != 'latin') {
    const sameScriptFallback = cityMatch.alternateNames.find(
      (item) =>
          detectPrimaryScript(item) == preferredScript &&
          normalizeLookupValue(item) != normalizeLookupValue(city.value),
    );
    if (sameScriptFallback != null) {
      return sameScriptFallback;
    }
  }

  if (normalizeLookupValue(nativeCountryName) != normalizeLookupValue(countryName)) {
    const latinFallback = cityMatch.alternateNames.find(
      (item) =>
          !hasNonLatinCharacters(item) &&
          normalizeLookupValue(item) != normalizeLookupValue(city.value),
    );
    if (latinFallback != null) {
      return latinFallback;
    }
  }

  return city.displayName || city.value;
}

async function collectCityMatches(lookup, geonamesCitiesPath) {
  const targetsByCountry = new Map();

  lookup.countries.forEach((country, countryIndex) => {
    const iso2 = String(country.iso2 ?? '').trim().toUpperCase();
    if (!iso2) {
      return;
    }

    let countryTargets = targetsByCountry.get(iso2);
    if (countryTargets == null) {
      countryTargets = new Map();
      targetsByCountry.set(iso2, countryTargets);
    }

    (country.cities ?? []).forEach((rawCity, cityIndex) => {
      const city = toCityRecord(rawCity);
      const normalized = normalizeLookupValue(city.value);
      if (!normalized) {
        return;
      }

      countryTargets.set(normalized, {
        countryIndex,
        cityIndex,
        canonicalName: city.value,
      });
    });
  });

  const matches = new Map();

  const reader = readline.createInterface({
    input: fs.createReadStream(geonamesCitiesPath, { encoding: 'utf8' }),
    crlfDelay: Infinity,
  });

  for await (const line of reader) {
    if (!line) {
      continue;
    }

    const parts = line.split('\t');
    const countryCode = String(parts[8] ?? '').trim().toUpperCase();
    const countryTargets = targetsByCountry.get(countryCode);
    if (countryTargets == null) {
      continue;
    }

    const candidateMatches = new Map();

    const addCandidate = (rawValue, matchType) => {
      const normalized = normalizeLookupValue(rawValue);
      if (!normalized) {
        return;
      }

      const target = countryTargets.get(normalized);
      if (target == null || candidateMatches.has(normalized)) {
        return;
      }

      candidateMatches.set(normalized, { target, matchType });
    };

    addCandidate(parts[1], 'name');
    addCandidate(parts[2], 'ascii');

    const alternateNames = String(parts[3] ?? '')
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean);

    for (const alternateName of alternateNames) {
      addCandidate(alternateName, 'alternate');
    }

    if (candidateMatches.size == 0) {
      continue;
    }

    for (const { target, matchType } of candidateMatches.values()) {
      const key = `${target.countryIndex}:${target.cityIndex}`;
      const score = candidateScore(matchType, parts[7], parts[14]);
      const current = matches.get(key);
      if (current != null && current.score >= score) {
        continue;
      }

      matches.set(key, {
        geonameId: String(parts[0] ?? '').trim(),
        featureCode: String(parts[7] ?? '').trim(),
        score,
        name: String(parts[1] ?? '').trim(),
        asciiName: String(parts[2] ?? '').trim(),
        alternateNames,
      });
    }
  }

  return matches;
}

async function collectAlternateNames(altNamesPath, targetGeonameIds) {
  const altNamesByGeonameId = new Map();

  const reader = readline.createInterface({
    input: fs.createReadStream(altNamesPath, { encoding: 'utf8' }),
    crlfDelay: Infinity,
  });

  for await (const line of reader) {
    if (!line) {
      continue;
    }

    const parts = line.split('\t');
    const geonameId = String(parts[1] ?? '').trim();
    if (!targetGeonameIds.has(geonameId)) {
      continue;
    }

    const isoLanguage = String(parts[2] ?? '').trim().toLowerCase();
    const alternateName = String(parts[3] ?? '').trim();
    if (!isoLanguage || !alternateName) {
      continue;
    }

    let byLanguage = altNamesByGeonameId.get(geonameId);
    if (byLanguage == null) {
      byLanguage = new Map();
      altNamesByGeonameId.set(geonameId, byLanguage);
    }

    let names = byLanguage.get(isoLanguage);
    if (names == null) {
      names = [];
      byLanguage.set(isoLanguage, names);
    }

    names.push({
      name: alternateName,
      isPreferred: String(parts[4] ?? '') == '1',
      isShort: String(parts[5] ?? '') == '1',
      isColloquial: String(parts[6] ?? '') == '1',
      isHistoric: String(parts[7] ?? '') == '1',
    });
  }

  return altNamesByGeonameId;
}

async function main() {
  const lookupPath = path.resolve(readArg('--lookup') ?? defaultLookupPath);
  const countriesJsonPath = readArg('--countries-json');
  const geonamesCitiesPath = readArg('--geonames-cities');
  const geonamesAlternatePath = readArg('--geonames-alternate');
  const reportPath = readArg('--report');

  if (!countriesJsonPath || !geonamesCitiesPath) {
    throw new Error(
      'Missing required inputs. Pass --countries-json=<path> and --geonames-cities=<path>. Add --geonames-alternate=<path> to apply city local names.',
    );
  }

  const lookup = JSON.parse(await fsp.readFile(lookupPath, 'utf8'));
  const countriesData = JSON.parse(
    await fsp.readFile(path.resolve(countriesJsonPath), 'utf8'),
  );

  const cityMatches = await collectCityMatches(
    lookup,
    path.resolve(geonamesCitiesPath),
  );

  if (reportPath) {
    const report = [];
    lookup.countries.forEach((country, countryIndex) => {
      (country.cities ?? []).forEach((rawCity, cityIndex) => {
        const city = toCityRecord(rawCity);
        const match = cityMatches.get(`${countryIndex}:${cityIndex}`) ?? null;
        report.push({
          iso2: country.iso2,
          country: country.name,
          city: city.value,
          geonameId: match?.geonameId ?? null,
          geonameName: match?.name ?? null,
        });
      });
    });

    await fsp.writeFile(
      path.resolve(reportPath),
      `${JSON.stringify(report, null, 2)}\n`,
      'utf8',
    );
  }

  if (!geonamesAlternatePath) {
    console.log(
      `Matched ${cityMatches.size} major cities. No --geonames-alternate path was provided, so the lookup was not rewritten.`,
    );
    return;
  }

  const targetGeonameIds = new Set(
    Array.from(cityMatches.values())
        .map((match) => match.geonameId)
        .filter(Boolean),
  );

  const altNamesByGeonameId = await collectAlternateNames(
    path.resolve(geonamesAlternatePath),
    targetGeonameIds,
  );

  let localizedCountryCount = 0;
  let localizedCityCount = 0;

  const countries = lookup.countries.map((country, countryIndex) => {
    const countryData = countriesData[String(country.iso2 ?? '').trim().toUpperCase()] ?? null;
    const nativeName =
        String(countryData?.native ?? country.nativeName ?? country.name ?? '').trim() ||
        String(country.name ?? '').trim();
    const languages = Array.isArray(countryData?.languages)
        ? countryData.languages.map((language) => String(language))
        : Array.isArray(country.languages)
            ? country.languages.map((language) => String(language))
            : [];

    if (normalizeLookupValue(nativeName) != normalizeLookupValue(country.name)) {
      localizedCountryCount += 1;
    }

    const cities = (country.cities ?? []).map((rawCity, cityIndex) => {
      const city = toCityRecord(rawCity);
      const match = cityMatches.get(`${countryIndex}:${cityIndex}`) ?? null;
      const displayName = selectCityDisplayName(
        country.iso2,
        city,
        String(country.name ?? ''),
        nativeName,
        languages,
        match,
        altNamesByGeonameId,
      );

      if (normalizeLookupValue(displayName) != normalizeLookupValue(city.value)) {
        localizedCityCount += 1;
      }

      return {
        value: city.value,
        displayName,
      };
    });

    return {
      ...country,
      nativeName,
      languages,
      cities,
    };
  });

  const output = {
    metadata: {
      ...lookup.metadata,
      generatedAt: currentLocalDate(),
      localizationSource: {
        countries: 'countries-list 3.3.0',
        geonamesCities: 'GeoNames cities500',
        geonamesAlternateNames: 'GeoNames alternateNamesV2',
      },
      localizedCountryCount,
      localizedCityCount,
    },
    countries,
  };

  await fsp.writeFile(lookupPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');

  console.log(
    `Localized ${localizedCountryCount} countries and ${localizedCityCount} cities in ${lookupPath}.`,
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});