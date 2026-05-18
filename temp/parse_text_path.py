"""
Parse path 21 (main text, 352865 chars) from page10.svgz.
Extract all glyph positions, cluster into lines, count word-clusters.
"""
import re
import sys

def parse_path_movetos(d_str):
    """
    Parse SVG path d attribute and return absolute (x, y) for every M/m command.
    Only tracks M/m (moveto) to identify glyph start positions.
    For other commands, we just update the current position to maintain continuity.
    """
    positions = []
    cx, cy = 0.0, 0.0
    
    # Tokenizer: split into command chars and numbers
    token_pat = re.compile(r'([MmLlHhVvCcSsQqTtAaZz])|([+-]?\d*\.?\d+(?:[eE][+-]?\d+)?)')
    tokens = token_pat.findall(d_str)
    # Each token is (cmd, num) where one of them is empty
    flat = []
    for cmd, num in tokens:
        if cmd:
            flat.append(cmd)
        else:
            flat.append(float(num))
    
    i = 0
    cur_cmd = None
    
    def next_num():
        nonlocal i
        while i < len(flat) and isinstance(flat[i], str):
            # unexpected command - don't consume
            break
        if i < len(flat) and isinstance(flat[i], float):
            v = flat[i]
            i += 1
            return v
        return None
    
    while i < len(flat):
        t = flat[i]
        if isinstance(t, str):
            cur_cmd = t
            i += 1
        # implicit lineto after moveto for repeated coords
        
        if cur_cmd == 'M':
            x = next_num()
            y = next_num()
            if x is None or y is None: break
            cx, cy = x, y
            positions.append((cx, cy))
            # Subsequent coord pairs are implicit L
            cur_cmd = 'L_from_M'
        elif cur_cmd == 'L_from_M':
            if i < len(flat) and isinstance(flat[i], float):
                x = next_num(); y = next_num()
                if x is None or y is None: break
                cx, cy = x, y
            else:
                cur_cmd = None
        elif cur_cmd == 'm':
            dx = next_num()
            dy = next_num()
            if dx is None or dy is None: break
            cx += dx; cy += dy
            positions.append((cx, cy))
            # Subsequent coord pairs are implicit l
            cur_cmd = 'l_from_m'
        elif cur_cmd == 'l_from_m':
            if i < len(flat) and isinstance(flat[i], float):
                dx = next_num(); dy = next_num()
                if dx is None or dy is None: break
                cx += dx; cy += dy
            else:
                cur_cmd = None
        elif cur_cmd == 'L':
            x = next_num(); y = next_num()
            if x is None or y is None: break
            cx, cy = x, y
        elif cur_cmd == 'l':
            dx = next_num(); dy = next_num()
            if dx is None or dy is None: break
            cx += dx; cy += dy
        elif cur_cmd == 'H':
            x = next_num()
            if x is None: break
            cx = x
        elif cur_cmd == 'h':
            dx = next_num()
            if dx is None: break
            cx += dx
        elif cur_cmd == 'V':
            y = next_num()
            if y is None: break
            cy = y
        elif cur_cmd == 'v':
            dy = next_num()
            if dy is None: break
            cy += dy
        elif cur_cmd == 'C':
            x1=next_num(); y1=next_num(); x2=next_num(); y2=next_num()
            x=next_num(); y=next_num()
            if any(v is None for v in [x1,y1,x2,y2,x,y]): break
            cx, cy = x, y
        elif cur_cmd == 'c':
            dx1=next_num(); dy1=next_num(); dx2=next_num(); dy2=next_num()
            dx=next_num(); dy=next_num()
            if any(v is None for v in [dx1,dy1,dx2,dy2,dx,dy]): break
            cx += dx; cy += dy
        elif cur_cmd == 'S':
            x2=next_num(); y2=next_num(); x=next_num(); y=next_num()
            if any(v is None for v in [x2,y2,x,y]): break
            cx, cy = x, y
        elif cur_cmd == 's':
            dx2=next_num(); dy2=next_num(); dx=next_num(); dy=next_num()
            if any(v is None for v in [dx2,dy2,dx,dy]): break
            cx += dx; cy += dy
        elif cur_cmd == 'Q':
            x1=next_num(); y1=next_num(); x=next_num(); y=next_num()
            if any(v is None for v in [x1,y1,x,y]): break
            cx, cy = x, y
        elif cur_cmd == 'q':
            dx1=next_num(); dy1=next_num(); dx=next_num(); dy=next_num()
            if any(v is None for v in [dx1,dy1,dx,dy]): break
            cx += dx; cy += dy
        elif cur_cmd in ('T', 't'):
            if cur_cmd == 'T':
                x=next_num(); y=next_num()
                if x is None or y is None: break
                cx, cy = x, y
            else:
                dx=next_num(); dy=next_num()
                if dx is None or dy is None: break
                cx += dx; cy += dy
        elif cur_cmd in ('A', 'a'):
            rx=next_num(); ry=next_num(); rot=next_num()
            laf=next_num(); sf=next_num()
            if cur_cmd == 'A':
                x=next_num(); y=next_num()
                if any(v is None for v in [rx,ry,rot,laf,sf,x,y]): break
                cx, cy = x, y
            else:
                dx=next_num(); dy=next_num()
                if any(v is None for v in [rx,ry,rot,laf,sf,dx,dy]): break
                cx += dx; cy += dy
        elif cur_cmd in ('Z', 'z'):
            pass
        else:
            # Unknown, try to skip
            i += 1
    
    return positions


def cluster_by_y(positions, tolerance=2.5):
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


def count_word_clusters(xs, gap_threshold=2.0):
    """Given sorted-descending X values (RTL), count word clusters."""
    if not xs:
        return 0, []
    xs_sorted = sorted(xs, reverse=True)
    clusters = 1
    boundaries = []
    for j in range(1, len(xs_sorted)):
        gap = xs_sorted[j-1] - xs_sorted[j]
        if gap > gap_threshold:
            clusters += 1
            boundaries.append((xs_sorted[j-1], xs_sorted[j], gap))
    return clusters, boundaries


def main():
    content = open('page10.svgz', encoding='utf-8').read()
    
    # Extract path 21 (the main text path - 352865 chars)
    tag_starts = [m.start() for m in re.finditer('<path', content)]
    print(f"Total paths: {len(tag_starts)}")
    
    path_data_list = []
    for i, start in enumerate(tag_starts):
        end = content.find('>', start)
        tag_str = content[start:end+1]
        d_match = re.search(r'\bd="([^"]*)"', tag_str)
        d = d_match.group(1) if d_match else ''
        path_data_list.append({'idx': i+1, 'len': len(d), 'd': d})
    
    # Get path 21 (largest)
    main_path = sorted(path_data_list, key=lambda x: -x['len'])[0]
    print(f"Main text path: path {main_path['idx']}, len={main_path['len']}")
    
    print("Parsing moveto commands...")
    positions = parse_path_movetos(main_path['d'])
    print(f"Moveto positions found: {len(positions)}")
    
    if len(positions) < 10:
        print("Too few positions! Dumping first 500 chars of d attr:")
        print(main_path['d'][:500])
        return
    
    print(f"Y range: {min(p[1] for p in positions):.2f} to {max(p[1] for p in positions):.2f}")
    print(f"X range: {min(p[0] for p in positions):.2f} to {max(p[0] for p in positions):.2f}")
    
    # Cluster by Y
    lines = cluster_by_y(positions, tolerance=2.5)
    print(f"\nLine clusters: {len(lines)}")
    
    sorted_lines = sorted(lines.items())
    
    # Known line baselines (from ayah marker analysis):
    # Line 3: Y≈103.77, Line 5: Y≈157.46, Line 7: Y≈210.77, Line 8: Y≈238.09
    # Line 9: Y≈264.18, Line 11: Y≈317.51
    known_markers = {3:103.77, 5:157.46, 7:210.77, 8:238.09, 9:264.18, 11:317.51}
    
    print(f"\n{'Line':5s} {'Y':8s} {'Glyphs':7s} {'Words':6s}")
    print("-"*40)
    
    # API word counts per line (from our mushaf_layout_mushaf5.json, page 10)
    api_word_counts = {
        1: 7,   # إِنَّ ٱلَّذِينَ ءَامَنُواْ وَٱلَّذِينَ هَادُواْ وَٱلنَّصَٰرَىٰ وَٱلصَّٰبِـِٔينَ
        2: 9,   # مَنۡ ءَامَنَ بِٱللَّهِ وَٱلۡيَوۡمِ ٱلۡأٓخِرِ وَعَمِلَ صَٰلِحٗا فَلَهُمۡ أَجۡرُهُمۡ (+ some markers)
        3: 10,  # عِندَ...وَإِذۡ (9 words + 1 marker)
        4: 9,   # أَخَذۡنَا...ءَاتَيۡنَٰكُم
        5: 12,  # بِقُوَّةٖ...مِّنۢ (10 words + 1 marker + word)
        6: 9,   # بَعۡدِ...مِّنَ
        7: 11,  # ٱلۡخَٰسِرِينَ...ٱلسَّبۡتِ (9 words + 2 markers)
        8: 11,  # فَقُلۡنَا...لِّمَا (9 words + 1 marker + word)
        9: 11,  # بَيۡنَ...قَالَ (9 words + 1 marker + 1 word)
        10: 12, # مُوسَىٰ...أَتَتَّخِذُنَا (12 words)
        11: 12, # هُزُوٗاۖ...قَالُواْ (10 words + 1 marker + 1 word)
        12: 14, # ٱدۡعُ...فَارِضٞ (14 words)
        13: 9,  # وَلَا...٦٨ (8 words + 1 marker)
        14: 11, # قَالُواْ...يَقُولُ (11 words)
        15: 8,  # إِنَّهَا...٦٩ (7 words + 1 marker)
    }
    
    for line_idx, (y, pts) in enumerate(sorted_lines, 1):
        xs = [p[0] for p in pts]
        wc, boundaries = count_word_clusters(xs, gap_threshold=2.0)
        api_wc = api_word_counts.get(line_idx, '?')
        diff = '' if api_wc == '?' else f"  API={api_wc} {'MATCH' if wc == api_wc else 'DIFF'}"
        print(f"Line {line_idx:2d} (Y={y:6.2f}): {len(pts):4d} glyphs, {wc:3d} word-clusters{diff}")
    
    # Also print with gap_threshold=1.5
    print("\n--- With gap_threshold=1.5 ---")
    for line_idx, (y, pts) in enumerate(sorted_lines, 1):
        xs = [p[0] for p in pts]
        wc, _ = count_word_clusters(xs, gap_threshold=1.5)
        api_wc = api_word_counts.get(line_idx, '?')
        diff = '' if api_wc == '?' else f"  API={api_wc} {'MATCH' if wc == api_wc else 'DIFF'}"
        print(f"Line {line_idx:2d} (Y={y:6.2f}): {wc:3d} word-clusters{diff}")


if __name__ == '__main__':
    main()
