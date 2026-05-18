"""Find the main text path by looking at all 21 path d attribute sizes"""
import re

content = open('page10.svgz', encoding='utf-8').read()
print(f"Total length: {len(content)}")

# Find all path elements and extract their d attributes
# Handle both <path d="..." and <path fill="..." d="..." etc.
tag_starts = [m.start() for m in re.finditer('<path', content)]
print(f"Path tags: {len(tag_starts)}")

path_data = []
for i, start in enumerate(tag_starts):
    # Find the end of this path tag (either /> or >)
    end = content.find('>', start)
    if end == -1:
        continue
    tag_str = content[start:end+1]
    
    # Extract d attribute
    d_match = re.search(r'\bd="([^"]*)"', tag_str)
    if d_match:
        d = d_match.group(1)
    else:
        d = ''
    
    # Extract fill
    fill_match = re.search(r'\bfill="([^"]*)"', tag_str)
    fill = fill_match.group(1) if fill_match else ''
    
    # Get first coord
    first_match = re.match(r'\s*[mM]\s*([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)', d)
    first_coord = (float(first_match.group(1)), float(first_match.group(2))) if first_match else (None, None)
    
    path_data.append({
        'idx': i+1,
        'len': len(d),
        'fill': fill,
        'first_coord': first_coord
    })
    print(f"Path {i+1:2d}: fill={fill!r:12s} len={len(d):6d}  first={first_coord}")

print(f"\nLargest paths:")
for p in sorted(path_data, key=lambda x: -x['len'])[:5]:
    print(f"  Path {p['idx']}: len={p['len']} first={p['first_coord']}")
