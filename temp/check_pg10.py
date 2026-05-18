import json
with open(r'E:\Sahifati\frontend_users\ui\assets\json\mushaf_layout_mushaf5.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
pg10 = data['pages'][9]
print("Page 10, surah 2 ayah 62 words:")
for line in pg10['lines']:
    for w in line['words']:
        if w[0] == 2 and w[1] == 62:
            ln = line['lineNumber']
            print(f"  line {ln}: {w[2]}")
print()
print("Line 1 words on page 10:")
for line in pg10['lines']:
    if line['lineNumber'] == 1:
        for w in line['words']:
            print(f"  {w[2]}")
