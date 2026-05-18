import json
with open(r'E:\Sahifati\frontend_users\ui\assets\json\mushaf_layout_mushaf5.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Check page 10: ayah 68 marker should be on line 14
pg10 = data['pages'][9]
for line in pg10['lines']:
    for w in line['words']:
        if w[1] == 68 and w[3] == 1:
            ln = line['lineNumber']
            print(f"Page 10 ayah marker 68: line {ln} (expected 14)")

# Check page 6: ayah 30 marker should be on line 3
pg6 = data['pages'][5]
for line in pg6['lines']:
    for w in line['words']:
        if w[1] == 30 and w[3] == 1:
            ln = line['lineNumber']
            print(f"Page 6 ayah marker 30: line {ln} (expected 3)")

# Page 10 line structure
lines_pg10 = [(l['lineNumber'], len(l['words'])) for l in pg10['lines']]
print(f"Page 10 lines (lineNum, wordCount): {lines_pg10}")

# Verify total word count unchanged
total = sum(len(l['words']) for p in data['pages'] for l in p['lines'])
print(f"Total words: {total} (expected 83665)")
