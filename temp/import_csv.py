"""
Re-import corrected CSV back to mushaf_layout_mushaf5.json
Usage: python import_csv.py

Reads mushaf_words.csv (after user has edited line numbers),
then reconstructs and overwrites the JSON.

IMPORTANT: Do NOT change word order or add/remove rows in the CSV.
Only modify the 'line' column (column index 2).
"""
import json
import csv
import os
import shutil
from collections import defaultdict
from datetime import datetime

csv_path = r'E:\Sahifati\frontend_users\ui\temp\mushaf_words.csv'
json_path = r'E:\Sahifati\frontend_users\ui\assets\json\mushaf_layout_mushaf5.json'

print(f"Reading corrected CSV: {csv_path}")

# page_num -> line_num -> list of words
pages_dict = defaultdict(lambda: defaultdict(list))

with open(csv_path, 'r', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    header = next(reader)
    
    expected = ['word_index', 'page', 'line', 'surah', 'ayah', 'pos_in_ayah', 'word_text', 'is_marker']
    if header != expected:
        print(f"ERROR: Unexpected header: {header}")
        print(f"Expected: {expected}")
        exit(1)
    
    row_count = 0
    for row in reader:
        word_index, page, line, surah, ayah, pos, text, is_marker = row
        page_num = int(page)
        line_num = int(line)
        word = [int(surah), int(ayah), text, int(is_marker)]
        pages_dict[page_num][line_num].append(word)
        row_count += 1

print(f"Loaded {row_count} words across {len(pages_dict)} pages")

# Build the new JSON structure
pages_list = []
for page_num in sorted(pages_dict.keys()):
    lines_dict = pages_dict[page_num]
    lines_list = []
    for line_num in sorted(lines_dict.keys()):
        lines_list.append({
            "lineNumber": line_num,
            "words": lines_dict[line_num]
        })
    pages_list.append({
        "pageNumber": page_num,
        "lines": lines_list
    })

new_data = {
    "mushaf": 5,
    "generatedAt": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S"),
    "pages": pages_list
}

# Backup the original
backup_path = json_path + f".bak_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
shutil.copy2(json_path, backup_path)
print(f"Backup saved: {backup_path}")

# Write new JSON
with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(new_data, f, ensure_ascii=False, separators=(',', ':'))

size = os.path.getsize(json_path)
print(f"JSON written: {json_path} ({size:,} bytes)")
print("Done! Run 'flutter build web --release' to apply changes.")
