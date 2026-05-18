"""
Parse the main text compound path from maknoon.com SVG page 10.
Track all moveto commands to find glyph positions, then cluster into lines/words.
"""
import re
import sys
from collections import defaultdict

def parse_path_coords(d_str):
    """
    Parse SVG path d attribute and track the current position for each M/m command.
    Returns list of (x, y) absolute positions for each moveto.
    """
    # Tokenize the path: split into commands and numbers
    # Path commands: M m L l H h V v C c S s Q q T t A a Z z
    tokens = re.findall(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?\d*\.?\d+(?:e[-+]?\d+)?', d_str)
    
    positions = []
    cx, cy = 0.0, 0.0  # current position
    i = 0
    
    while i < len(tokens):
        cmd = tokens[i]
        i += 1
        
        if cmd == 'M':  # absolute moveto
            while i < len(tokens) and not tokens[i].isalpha():
                x = float(tokens[i]); i += 1
                y = float(tokens[i]); i += 1
                cx, cy = x, y
                positions.append((cx, cy))
        
        elif cmd == 'm':  # relative moveto
            first = True
            while i < len(tokens) and not tokens[i].isalpha():
                dx = float(tokens[i]); i += 1
                dy = float(tokens[i]); i += 1
                cx += dx
                cy += dy
                positions.append((cx, cy))
                first = False
        
        elif cmd in ('L', 'l', 'H', 'h', 'V', 'v'):
            # Line commands - consume parameters but only update position
            if cmd == 'L':
                while i < len(tokens) and not tokens[i].isalpha():
                    cx = float(tokens[i]); i += 1
                    cy = float(tokens[i]); i += 1
            elif cmd == 'l':
                while i < len(tokens) and not tokens[i].isalpha():
                    cx += float(tokens[i]); i += 1
                    cy += float(tokens[i]); i += 1
            elif cmd == 'H':
                while i < len(tokens) and not tokens[i].isalpha():
                    cx = float(tokens[i]); i += 1
            elif cmd == 'h':
                while i < len(tokens) and not tokens[i].isalpha():
                    cx += float(tokens[i]); i += 1
            elif cmd == 'V':
                while i < len(tokens) and not tokens[i].isalpha():
                    cy = float(tokens[i]); i += 1
            elif cmd == 'v':
                while i < len(tokens) and not tokens[i].isalpha():
                    cy += float(tokens[i]); i += 1
        
        elif cmd in ('C', 'c'):
            # Cubic bezier - 6 params per command
            if cmd == 'C':
                while i < len(tokens) and not tokens[i].isalpha():
                    x1 = float(tokens[i]); i += 1
                    y1 = float(tokens[i]); i += 1
                    x2 = float(tokens[i]); i += 1
                    y2 = float(tokens[i]); i += 1
                    cx = float(tokens[i]); i += 1
                    cy = float(tokens[i]); i += 1
            else:  # 'c'
                while i < len(tokens) and not tokens[i].isalpha():
                    dx1 = float(tokens[i]); i += 1
                    dy1 = float(tokens[i]); i += 1
                    dx2 = float(tokens[i]); i += 1
                    dy2 = float(tokens[i]); i += 1
                    cx += float(tokens[i]); i += 1
                    cy += float(tokens[i]); i += 1
        
        elif cmd in ('S', 's'):
            # Smooth cubic bezier - 4 params
            if cmd == 'S':
                while i < len(tokens) and not tokens[i].isalpha():
                    x2 = float(tokens[i]); i += 1
                    y2 = float(tokens[i]); i += 1
                    cx = float(tokens[i]); i += 1
                    cy = float(tokens[i]); i += 1
            else:
                while i < len(tokens) and not tokens[i].isalpha():
                    dx2 = float(tokens[i]); i += 1
                    dy2 = float(tokens[i]); i += 1
                    cx += float(tokens[i]); i += 1
                    cy += float(tokens[i]); i += 1
        
        elif cmd in ('Q', 'q'):
            # Quadratic bezier - 4 params
            if cmd == 'Q':
                while i < len(tokens) and not tokens[i].isalpha():
                    x1 = float(tokens[i]); i += 1
                    y1 = float(tokens[i]); i += 1
                    cx = float(tokens[i]); i += 1
                    cy = float(tokens[i]); i += 1
            else:
                while i < len(tokens) and not tokens[i].isalpha():
                    dx1 = float(tokens[i]); i += 1
                    dy1 = float(tokens[i]); i += 1
                    cx += float(tokens[i]); i += 1
                    cy += float(tokens[i]); i += 1
        
        elif cmd in ('T', 't'):
            # Smooth quadratic - 2 params
            if cmd == 'T':
                while i < len(tokens) and not tokens[i].isalpha():
                    cx = float(tokens[i]); i += 1
                    cy = float(tokens[i]); i += 1
            else:
                while i < len(tokens) and not tokens[i].isalpha():
                    cx += float(tokens[i]); i += 1
                    cy += float(tokens[i]); i += 1
        
        elif cmd in ('Z', 'z'):
            pass  # Close path, no coords
        
        elif cmd == 'A' or cmd == 'a':
            # Elliptical arc - 7 params
            if cmd == 'A':
                while i < len(tokens) and not tokens[i].isalpha():
                    rx = float(tokens[i]); i += 1
                    ry = float(tokens[i]); i += 1
                    rot = float(tokens[i]); i += 1
                    laf = float(tokens[i]); i += 1
                    sf = float(tokens[i]); i += 1
                    cx = float(tokens[i]); i += 1
                    cy = float(tokens[i]); i += 1
            else:
                while i < len(tokens) and not tokens[i].isalpha():
                    rx = float(tokens[i]); i += 1
                    ry = float(tokens[i]); i += 1
                    rot = float(tokens[i]); i += 1
                    laf = float(tokens[i]); i += 1
                    sf = float(tokens[i]); i += 1
                    cx += float(tokens[i]); i += 1
                    cy += float(tokens[i]); i += 1
    
    return positions


def cluster_by_y(positions, tolerance=2.0):
    """Group positions by Y coordinate with given tolerance."""
    lines = {}
    for x, y in positions:
        matched = None
        for ly in lines:
            if abs(y - ly) <= tolerance:
                matched = ly
                break
        if matched is None:
            lines[y] = []
            matched = y
        lines[matched].append((x, y))
    return lines


def count_words_in_line(positions_in_line, gap_threshold=1.8):
    """
    Count word clusters in a line based on X coordinate gaps.
    Arabic text: higher X = start of line (RTL), lower X = end of line.
    """
    if not positions_in_line:
        return 0, []
    
    sorted_x = sorted([p[0] for p in positions_in_line], reverse=True)  # RTL
    word_count = 1
    word_starts = [sorted_x[0]]
    
    for i in range(1, len(sorted_x)):
        gap = sorted_x[i-1] - sorted_x[i]
        if gap > gap_threshold:
            word_count += 1
            word_starts.append(sorted_x[i])
    
    return word_count, word_starts


def main():
    svg_path = 'page10.svgz'
    print(f"Reading {svg_path}...")
    with open(svg_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract path 9 (the main text - largest path)
    path_regex = re.compile(r'<path\s+d="([^"]{1,500000})"', re.DOTALL)
    all_paths = path_regex.findall(content)
    print(f"Total paths: {len(all_paths)}")
    
    # Sort by length to find the main text path
    paths_with_len = [(len(d), i, d) for i, d in enumerate(all_paths)]
    paths_with_len.sort(reverse=True)
    
    for length, idx, d in paths_with_len[:3]:
        print(f"  Path {idx+1}: len={length}")
    
    # Use the largest path as main text
    main_path_d = paths_with_len[0][2]
    print(f"\nParsing main text path ({len(main_path_d)} chars)...")
    
    positions = parse_path_coords(main_path_d)
    print(f"Extracted {len(positions)} glyph positions")
    
    if not positions:
        print("ERROR: No positions extracted!")
        return
    
    print(f"Y range: {min(p[1] for p in positions):.1f} to {max(p[1] for p in positions):.1f}")
    print(f"X range: {min(p[0] for p in positions):.1f} to {max(p[0] for p in positions):.1f}")
    
    # Cluster by Y
    lines = cluster_by_y(positions, tolerance=2.5)
    print(f"\nLines found: {len(lines)}")
    
    # Sort lines by Y
    sorted_lines = sorted(lines.items())
    
    print("\n--- Glyph count per line (sorted by Y) ---")
    for line_idx, (y, pts) in enumerate(sorted_lines, 1):
        wc, _ = count_words_in_line(pts, gap_threshold=1.8)
        print(f"  SVG Line {line_idx:2d} (Y={y:.1f}): {len(pts):3d} glyphs → ~{wc} word-clusters")


if __name__ == '__main__':
    main()
