"""
Extract SVG path structure for page 10 - find Y coordinates and glyph density
"""
import re, sys

def main():
    svg_path = 'page10.svgz'
    with open(svg_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print(f"File length: {len(content)}")
    
    # Find all path d= attributes and their starting coords
    path_regex = re.compile(r'<path\s+d="([^"]{1,200000})"', re.DOTALL)
    paths = path_regex.findall(content)
    print(f"Paths found: {len(paths)}")
    
    for i, d in enumerate(paths):
        # Count how many m/M moveto commands are in this path
        movetos = re.findall(r'(?:^|[ \n])[mM](?=[ \n\d+-])', d)
        
        # Get first coordinate
        first = re.match(r'\s*[mM]\s*([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)', d)
        if first:
            x, y = float(first.group(1)), float(first.group(2))
        else:
            x, y = None, None
        
        print(f"Path {i+1}: first=({x},{y}) len={len(d)} movetos_approx={len(movetos)}")

if __name__ == '__main__':
    main()
