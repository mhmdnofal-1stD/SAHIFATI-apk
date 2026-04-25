import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const defaultLookupPath = path.join(rootDir, 'assets', 'json', 'profile_location_lookup.json');

function readArg(name) {
  const prefix = `${name}=`;
  const match = process.argv.find((arg) => arg.startsWith(prefix));
  return match ? match.slice(prefix.length) : null;
}

function normalizePopulation(value) {
  const parsed = Number.parseFloat(String(value ?? '').trim());
  return Number.isFinite(parsed) ? parsed : 0;
}

function normalizedCityKey(value) {
  return String(value ?? '').trim().toLocaleLowerCase('en');
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

function capitalRank(value) {
  const normalized = String(value ?? '').trim().toLocaleLowerCase('en');
  if (normalized == 'primary') {
    return 0;
  }
  if (normalized == 'admin') {
    return 1;
  }
  return 99;
}

function currentLocalDate() {
  const now = new Date();
  const year = String(now.getFullYear());
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function main() {
  const citiesPathArg = readArg('--cities-json');
  if (!citiesPathArg) {
    throw new Error(
      'Missing --cities-json=<path>. Pass a SimpleMaps-compatible world cities JSON file that includes capital values.',
    );
  }

  const lookupPath = path.resolve(readArg('--lookup') ?? defaultLookupPath);
  const citiesPath = path.resolve(citiesPathArg);

  const lookup = JSON.parse(await fs.readFile(lookupPath, 'utf8'));
  const worldCities = JSON.parse(await fs.readFile(citiesPath, 'utf8'));

  const majorCitiesByIso2 = new Map();

  for (const entry of worldCities) {
    const rank = capitalRank(entry.capital);
    if (rank > 1) {
      continue;
    }

    const iso2 = String(entry.iso2 ?? '').trim().toUpperCase();
    const cityName = String(entry.city ?? '').trim();
    if (!iso2 || !cityName) {
      continue;
    }

    let countryCities = majorCitiesByIso2.get(iso2);
    if (countryCities == null) {
      countryCities = new Map();
      majorCitiesByIso2.set(iso2, countryCities);
    }

    const key = normalizedCityKey(cityName);
    const candidate = {
      name: cityName,
      rank,
      population: normalizePopulation(entry.population),
    };

    const current = countryCities.get(key);
    if (
      current == null ||
      candidate.rank < current.rank ||
      (candidate.rank == current.rank && candidate.population > current.population)
    ) {
      countryCities.set(key, candidate);
    }
  }

  const missingCountries = [];
  const countries = lookup.countries.map((country) => {
    const existingCityLabels = new Map(
      (country.cities ?? []).map((city) => {
        const record = toCityRecord(city);
        return [normalizedCityKey(record.value), record.displayName || record.value];
      }),
    );

    const majorCities = Array.from(
      majorCitiesByIso2.get(String(country.iso2 ?? '').trim().toUpperCase())?.values() ?? [],
    )
      .sort((left, right) => {
        if (left.rank != right.rank) {
          return left.rank - right.rank;
        }
        if (left.population != right.population) {
          return right.population - left.population;
        }
        return left.name.localeCompare(right.name, 'en');
      })
      .map((item) => item.name);

    if (majorCities.length === 0) {
      missingCountries.push(country.name);
    }

    return {
      ...country,
      cities: majorCities.map((cityName) => ({
        value: cityName,
        displayName: existingCityLabels.get(normalizedCityKey(cityName)) ?? cityName,
      })),
    };
  });

  const output = {
    metadata: {
      ...lookup.metadata,
      generatedAt: currentLocalDate(),
      source:
        'Normalized local lookup generated from country_picker 2.0.27 phone-code data and world-cities-json 1.0.1 (SimpleMaps World Cities, CC BY 4.0), filtered to cities where capital is primary or admin',
      cityFilter: ['primary', 'admin'],
      countryCount: countries.length,
      missingMajorCityCountries: missingCountries,
    },
    countries,
  };

  await fs.writeFile(lookupPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');

  console.log(
    `Updated ${lookupPath} with major cities only for ${countries.length} countries; missing=${missingCountries.length}`,
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});