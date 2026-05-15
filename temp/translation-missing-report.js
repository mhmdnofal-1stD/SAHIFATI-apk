const fs = require('fs');
const path = require('path');

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.isFile() && full.endsWith('.dart')) out.push(full);
  }
  return out;
}

const root = process.cwd();
const files = walk(path.join(root, 'lib'));
const refs = new Map();

for (const file of files) {
  const text = fs.readFileSync(file, 'utf8');
  for (const match of text.matchAll(/['\"]([A-Za-z0-9_\.\-]+)['\"]\.(?:tr|trParams)\b/g)) {
    const key = match[1];
    if (!refs.has(key)) refs.set(key, []);
    refs.get(key).push(file);
  }
}

const ar = JSON.parse(fs.readFileSync(path.join(root, 'assets', 'json', 'intl_ar.json'), 'utf8'));
const missing = [...refs.keys()].filter((key) => !(key in ar)).sort();
const groups = new Map();

for (const key of missing) {
  const filesForKey = [...new Set(refs.get(key))];
  for (const file of filesForKey) {
    if (!groups.has(file)) groups.set(file, []);
    groups.get(file).push(key);
  }
}

const orderedGroups = [...groups.entries()].sort((a, b) => a[0].localeCompare(b[0]));
console.log(`MISSING_TOTAL ${missing.length}`);
for (const [file, keys] of orderedGroups) {
  console.log(`FILE ${path.relative(root, file)} ${keys.length}`);
  for (const key of keys.sort()) {
    console.log(`  - ${key}`);
  }
}
