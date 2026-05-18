"""
Generate CSV of all Quran words from mushaf_layout_mushaf5.json
Output: word_index, page, line, surah, ayah, position_in_ayah, word_text, is_marker
"""
import json
import csv
import sys
import os

json_path = r'E:\Sahifati\frontend_users\ui\assets\json\mushaf_layout_mushaf5.json'
csv_path = r'E:\Sahifati\frontend_users\ui\temp\mushaf_words.csv'

print(f"Reading {json_path}...")
with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

print("Generating CSV...")
word_index = 0
ayah_word_position = {}  # (surah, ayah) -> current position

with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['word_index', 'page', 'line', 'surah', 'ayah', 'pos_in_ayah', 'word_text', 'is_marker'])
    
    for page in data['pages']:
        page_num = page['pageNumber']
        for line in page['lines']:
            line_num = line['lineNumber']
            for word in line['words']:
                surah = word[0]
                ayah = word[1]
                text = word[2]
                is_marker = word[3]
                
                key = (surah, ayah)
                if key not in ayah_word_position:
                    ayah_word_position[key] = 0
                ayah_word_position[key] += 1
                pos = ayah_word_position[key]
                
                word_index += 1
                writer.writerow([word_index, page_num, line_num, surah, ayah, pos, text, is_marker])

print(f"Done! CSV written: {csv_path}")
print(f"Total words: {word_index}")
print(f"File size: {os.path.getsize(csv_path):,} bytes")

# Print page 10 preview
print("\n--- Page 10 preview ---")
print(f"{'idx':>6} {'pg':>3} {'ln':>3} {'s':>3} {'a':>4} {'pos':>4} {'text':<30} {'mk':>3}")
print("-"*60)
with open(csv_path, 'r', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    next(reader)  # skip header
    for row in reader:
        if int(row[1]) == 10:
            print(f"{row[0]:>6} {row[1]:>3} {row[2]:>3} {row[3]:>3} {row[4]:>4} {row[5]:>4} {row[6]:<30} {row[7]:>3}")
        elif int(row[1]) > 10:
            break
