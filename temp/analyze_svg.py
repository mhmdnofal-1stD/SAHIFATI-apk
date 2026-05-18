"""
Analyze maknoon.com SVG for page 10 to extract word-per-line counts
using path coordinate clustering.
"""
import re
import sys

SVG_PATH = 'page10.svgz'

def first_abs_coord(d_attr):
    """Extract the first absolute coordinate from a path's d attribute."""
    # relative moveto (lowercase m) at start - these are relative to (0,0) so still absolute
    # 'm x y' at start of path
    m = re.match(r'\s*[mM]\s*([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)', d_attr)
    if m:
        return float(m.group(1)), float(m.group(2))
    return None

def main():
    print(f"Reading {SVG_PATH}...")
    with open(SVG_PATH, encoding='utf-8') as f:
        svg_text = f.read()
    
    print(f"File size: {len(svg_text):,} chars")
    
    # Extract all path d attributes
    d_attrs = re.findall(r'<path\b[^>]*\bd="([^"]+)"', svg_text)
    print(f"Total <path> elements: {len(d_attrs)}")
    
    if not d_attrs:
        print("ERROR: No path elements found!")
        return
    
    # Extract also fill color per path
    fill_colors = re.findall(r'<path\b([^>]*)>', svg_text)
    
    # Get first coordinate of each path
    coords = []
    skipped = 0
    for d in d_attrs:
        coord = first_abs_coord(d)
        if coord:
            coords.append(coord)
        else:
            skipped += 1
    
    print(f"Paths with extracted coords: {len(coords)}, skipped: {skipped}")
    print(f"Sample Y values (first 20): {[round(c[1],1) for c in coords[:20]]}")
    print()
    
    y_vals = [c[1] for c in coords]
    x_vals = [c[0] for c in coords]
    print(f"Y range: {min(y_vals):.2f} to {max(y_vals):.2f} (span {max(y_vals)-min(y_vals):.2f})")
    print(f"X range: {min(x_vals):.2f} to {max(x_vals):.2f} (span {max(x_vals)-min(x_vals):.2f})")
    
    # Cluster by Y coordinate (tolerance = 3 units)
    TOLERANCE = 3.0
    lines_dict = {}
    for x, y in coords:
        # Find if there's an existing cluster within tolerance
        found = False
        for ly in list(lines_dict.keys()):
            if abs(y - ly) <= TOLERANCE:
                lines_dict[ly].append((x, y))
                found = True
                break
        if not found:
            lines_dict[y] = [(x, y)]
    
    print(f"\nTotal Y-clusters (lines): {len(lines_dict)}")
    
    # Sort clusters by Y
    sorted_lines = sorted(lines_dict.items(), key=lambda item: item[0])
    
    print("\n--- Y clusters with glyph counts (sorted by Y) ---")
    for ly, glyphs in sorted_lines:
        print(f"  Y~{ly:.1f}: {len(glyphs)} glyphs")
    
    # Filter to "text lines" - clusters with enough glyphs (> 10)
    text_lines = [(ly, glyphs) for ly, glyphs in sorted_lines if len(glyphs) >= 10]
    print(f"\nText lines (>=10 glyphs): {len(text_lines)}")
    
    # For each text line, find word clusters by X-coordinate gaps
    # In RTL text, glyphs go from high X to low X
    print("\n--- Word clusters per line ---")
    line_word_counts = []
    for line_idx, (ly, glyphs) in enumerate(text_lines, 1):
        # Sort glyphs by X (descending for RTL)
        sorted_glyphs = sorted(glyphs, key=lambda g: g[0], reverse=True)
        x_positions = [g[0] for g in sorted_glyphs]
        
        # Find gaps between consecutive glyphs
        GAP_THRESHOLD = 1.5  # units gap that separates words
        word_count = 1
        words_start_x = [x_positions[0]] if x_positions else []
        
        for i in range(1, len(x_positions)):
            gap = x_positions[i-1] - x_positions[i]  # RTL: previous is higher X
            if gap > GAP_THRESHOLD:
                word_count += 1
                words_start_x.append(x_positions[i])
        
        line_word_counts.append(word_count)
        print(f"  Line {line_idx:2d} (Y~{ly:.0f}): {len(glyphs):3d} glyphs → {word_count:2d} word-clusters")
    
    print(f"\nSVG word-per-line summary: {line_word_counts}")

if __name__ == '__main__':
    main()
