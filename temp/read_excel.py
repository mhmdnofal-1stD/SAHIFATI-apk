"""
Read Excel corrections file and show what changed vs current JSON
Excel has only: word_index, line
"""
import openpyxl
import json

xlsx_path = r'E:\Sahifati\Public-data-\modify lines pages 1-100.xlsx'
json_path = r'E:\Sahifati\frontend_users\ui\assets\json\mushaf_layout_mushaf5.json'

print(f"Reading Excel: {xlsx_path}")
wb = openpyxl.load_workbook(xlsx_path, data_only=True)
ws = wb.active
print(f"Dimensions: {ws.dimensions}")

rows = list(ws.iter_rows(values_only=True))
header = rows[0]
print(f"Header: {header}")
print(f"Data rows: {len(rows)-1}")

# Build Excel lookup: word_index -> new_line
excel_lines = {}
for row in rows[1:]:
    if row[0] is None:
        continue
    try:
        excel_lines[int(row[0])] = int(row[1])
    except (TypeError, ValueError):
        continue

print(f"Excel entries loaded: {len(excel_lines)}")
wb.close()

# Read current JSON to build word_index -> (line, page, surah, ayah, text)
print("Reading JSON...")
with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

json_info = {}  # word_index -> dict
wi = 0
for page in data['pages']:
    pg = page['pageNumber']
    for line in page['lines']:
        ln = line['lineNumber']
        for word in line['words']:
            wi += 1
            json_info[wi] = {
                'line': ln, 'page': pg,
                'surah': word[0], 'ayah': word[1],
                'text': word[2], 'is_marker': word[3]
            }

print(f"JSON words indexed: {wi}")

# Find differences
changes = []
for word_idx, new_line in sorted(excel_lines.items()):
    info = json_info.get(word_idx)
    if info is None:
        print(f"  WARNING: word_index {word_idx} not found in JSON!")
        continue
    old_line = info['line']
    if old_line != new_line:
        changes.append({
            'word_index': word_idx,
            'page': info['page'],
            'surah': info['surah'],
            'ayah': info['ayah'],
            'text': info['text'],
            'old_line': old_line,
            'new_line': new_line
        })
        print(f"  idx={word_idx:5d} pg={info['page']:3d} s={info['surah']} a={info['ayah']} '{info['text']}': line {old_line} -> {new_line}")

print(f"\nTotal changes: {len(changes)}")
