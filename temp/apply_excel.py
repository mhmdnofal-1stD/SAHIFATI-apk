"""
Apply Excel line-number corrections to mushaf_layout_mushaf5.json
Excel has two columns: word_index, line
"""
import openpyxl
import json
import datetime
import shutil
import os

xlsx_path = r'E:\Sahifati\Public-data-\modify lines pages 1-100.xlsx'
json_path = r'E:\Sahifati\frontend_users\ui\assets\json\mushaf_layout_mushaf5.json'

# ── 1. Read Excel corrections ──────────────────────────────────────────────
print("Reading Excel corrections...")
wb = openpyxl.load_workbook(xlsx_path, data_only=True)
ws = wb.active
rows = list(ws.iter_rows(values_only=True))
header = rows[0]  # ('word_index', 'line')
excel_corrections = {}   # word_index -> new_line
for row in rows[1:]:
    if row[0] is None:
        continue
    try:
        excel_corrections[int(row[0])] = int(row[1])
    except (TypeError, ValueError):
        continue
wb.close()
print(f"  Excel corrections loaded: {len(excel_corrections)}")

# ── 2. Read JSON and flatten all words ────────────────────────────────────
print("Reading JSON...")
with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Flatten: list of dicts with (word_index, page_idx, line_number, word_data)
flat_words = []  # list of {wi, page_idx, line, word}
wi = 0
for page_idx, page in enumerate(data['pages']):
    for line in page['lines']:
        ln = line['lineNumber']
        for word in line['words']:
            wi += 1
            flat_words.append({
                'wi': wi,
                'page_idx': page_idx,
                'line': ln,
                'word': word
            })

print(f"  Total words indexed: {wi}")

# ── 3. Apply corrections ─────────────────────────────────────────────────
changed = 0
for fw in flat_words:
    if fw['wi'] in excel_corrections:
        new_line = excel_corrections[fw['wi']]
        if fw['line'] != new_line:
            fw['line'] = new_line
            changed += 1
print(f"  Changes applied: {changed}")

# ── 4. Rebuild JSON structure ──────────────────────────────────────────────
# For each page: group words by line number, sort by wi, rebuild lines array
print("Rebuilding JSON structure...")

for page_idx, page in enumerate(data['pages']):
    # Collect all words belonging to this page
    page_words = [fw for fw in flat_words if fw['page_idx'] == page_idx]
    
    # Group by line number
    line_groups = {}
    for fw in page_words:
        ln = fw['line']
        if ln not in line_groups:
            line_groups[ln] = []
        line_groups[ln].append(fw)
    
    # Sort words within each line by word_index (preserves reading order)
    for ln in line_groups:
        line_groups[ln].sort(key=lambda x: x['wi'])
    
    # Build new lines array, sorted by line number
    new_lines = []
    for ln in sorted(line_groups.keys()):
        new_lines.append({
            'lineNumber': ln,
            'words': [fw['word'] for fw in line_groups[ln]]
        })
    
    page['lines'] = new_lines

# ── 5. Backup and save ────────────────────────────────────────────────────
ts = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
backup_path = json_path + f'.bak_{ts}'
shutil.copy2(json_path, backup_path)
print(f"Backup saved: {os.path.basename(backup_path)}")

with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

file_size = os.path.getsize(json_path)
print(f"JSON saved: {file_size:,} bytes")
print(f"\nDone! {changed} words moved to corrected lines.")
