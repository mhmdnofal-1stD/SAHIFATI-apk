"""
Fast SVG path parser - extract all m/M moveto positions from path 21.
Uses character-by-character scanning for performance.
"""
import re
from collections import defaultdict

def fast_parse_movetos(d_str):
    """
    Scan path d attribute character by character.
    Track absolute position for every m/M command.
    """
    positions = []
    cx, cy = 0.0, 0.0
    
    n = len(d_str)
    i = 0
    cur_cmd = None
    
    def read_number(pos):
        """Read a floating point number starting at pos. Returns (value, new_pos)."""
        while pos < n and d_str[pos] in ' \t\n\r,':
            pos += 1
        if pos >= n:
            return None, pos
        # Optional sign
        start = pos
        if d_str[pos] in '+-':
            pos += 1
        # Digits before decimal
        while pos < n and d_str[pos].isdigit():
            pos += 1
        # Decimal
        if pos < n and d_str[pos] == '.':
            pos += 1
            while pos < n and d_str[pos].isdigit():
                pos += 1
        # Exponent
        if pos < n and d_str[pos] in 'eE':
            pos += 1
            if pos < n and d_str[pos] in '+-':
                pos += 1
            while pos < n and d_str[pos].isdigit():
                pos += 1
        if pos == start or (pos == start + 1 and d_str[start] in '+-'):
            return None, start
        return float(d_str[start:pos]), pos
    
    while i < n:
        c = d_str[i]
        
        if c.isalpha():
            cur_cmd = c
            i += 1
            
            if cur_cmd in ('Z', 'z'):
                continue
            
            # Read number pairs for this command
            while i < n and not d_str[i].isalpha():
                if d_str[i] in ' \t\n\r,':
                    i += 1
                    continue
                # Try to read a number
                num1, i = read_number(i)
                if num1 is None:
                    break
                
                if cur_cmd in ('H', 'h', 'V', 'v'):
                    if cur_cmd == 'H': cx = num1
                    elif cur_cmd == 'h': cx += num1
                    elif cur_cmd == 'V': cy = num1
                    elif cur_cmd == 'v': cy += num1
                    continue
                
                num2, i = read_number(i)
                if num2 is None:
                    break
                
                if cur_cmd == 'M':
                    cx, cy = num1, num2
                    positions.append((cx, cy))
                    cur_cmd = 'L'  # implicit lineto
                elif cur_cmd == 'm':
                    cx += num1; cy += num2
                    positions.append((cx, cy))
                    cur_cmd = 'l'  # implicit lineto
                elif cur_cmd in ('L', 'l'):
                    if cur_cmd == 'L': cx, cy = num1, num2
                    else: cx += num1; cy += num2
                elif cur_cmd in ('T', 't'):
                    if cur_cmd == 'T': cx, cy = num1, num2
                    else: cx += num1; cy += num2
                elif cur_cmd in ('S', 's', 'Q', 'q'):
                    # 4 params
                    num3, i = read_number(i)
                    num4, i = read_number(i)
                    if num3 is None: break
                    if cur_cmd == 'S': cx, cy = num3, num4
                    elif cur_cmd == 's': cx += num3; cy += num4
                    elif cur_cmd == 'Q': cx, cy = num3, num4
                    elif cur_cmd == 'q': cx += num3; cy += num4
                elif cur_cmd in ('C', 'c'):
                    # 6 params
                    num3, i = read_number(i)
                    num4, i = read_number(i)
                    num5, i = read_number(i)
                    num6, i = read_number(i)
                    if num3 is None: break
                    if cur_cmd == 'C': cx, cy = num5, num6
                    else: cx += num5; cy += num6
                elif cur_cmd in ('A', 'a'):
                    # 7 params: rx ry x-rot large-arc sweep x y
                    num3, i = read_number(i)
                    num4, i = read_number(i)
                    num5, i = read_number(i)
                    num6, i = read_number(i)
                    num7, i = read_number(i)
                    if num3 is None: break
                    if cur_cmd == 'A': cx, cy = num6, num7
                    else: cx += num6; cy += num7
        else:
            i += 1
    
    return positions


def cluster_by_y_merge(positions, tolerance=13.0):
    """
    Cluster positions into lines with a tolerance window.
    Uses merge approach: positions within tolerance of cluster center are merged.
    """
    # Sort by Y first
    sorted_pos = sorted(positions, key=lambda p: p[1])
    
    clusters = []  # Each cluster: {'center_y': float, 'points': [(x,y)...]}
    
    for x, y in sorted_pos:
        merged = False
        for cluster in clusters:
            if abs(y - cluster['center_y']) <= tolerance:
                cluster['points'].append((x, y))
                # Update center (running mean)
                cluster['center_y'] = sum(p[1] for p in cluster['points']) / len(cluster['points'])
                merged = True
                break
        if not merged:
            clusters.append({'center_y': y, 'points': [(x, y)]})
    
    return sorted(clusters, key=lambda c: c['center_y'])


def count_word_clusters(xs, gap_threshold=2.0):
    if not xs:
        return 0
    xs_sorted = sorted(xs, reverse=True)
    clusters = 1
    for j in range(1, len(xs_sorted)):
        if xs_sorted[j-1] - xs_sorted[j] > gap_threshold:
            clusters += 1
    return clusters


def main():
    import time
    
    t0 = time.time()
    content = open('page10.svgz', 'r', encoding='utf-8').read()
    print(f"Read file: {time.time()-t0:.2f}s")
    
    # Get main path (largest)
    tags = [m.start() for m in re.finditer('<path', content)]
    paths = []
    for s in tags:
        e = content.find('>', s)
        d_m = re.search(r'\bd="([^"]*)"', content[s:e+1])
        if d_m:
            paths.append(d_m.group(1))
    
    paths.sort(key=lambda x: -len(x))
    main_d = paths[0]
    print(f"Main path len: {len(main_d)}")
    
    t1 = time.time()
    positions = fast_parse_movetos(main_d)
    t2 = time.time()
    print(f"Parsed {len(positions)} positions in {t2-t1:.2f}s")
    
    if len(positions) < 100:
        print("WARNING: Too few positions!")
        return
    
    print(f"Y range: {min(p[1] for p in positions):.2f} to {max(p[1] for p in positions):.2f}")
    print(f"X range: {min(p[0] for p in positions):.2f} to {max(p[0] for p in positions):.2f}")
    
    # Known line baselines from ayah marker positions
    # Line 3:103.77, Line 5:157.46, Line 7:210.77, Line 8:238.09,
    # Line 9:264.18, Line 11:317.51, Line 14:398.36, Line 15:425.95
    # Expected line 1 baseline: ~50.34, Line 15: ~424.37
    # Line spacing: ~26.72 units
    
    # Try different tolerances to get ~15 clusters
    for tol in [10, 12, 13, 14, 15, 18]:
        clusters = cluster_by_y_merge(positions, tolerance=tol)
        if 10 <= len(clusters) <= 30:
            # API word counts per line for page 10
            api_wc = {1:7, 2:9, 3:10, 4:9, 5:12, 6:9, 7:11, 8:11,
                      9:11, 10:12, 11:12, 12:14, 13:9, 14:11, 15:8}
            
            print(f"\n=== tolerance={tol} → {len(clusters)} clusters ===")
            for idx, cl in enumerate(clusters, 1):
                xs = [p[0] for p in cl['points']]
                wc2 = count_word_clusters(xs, gap_threshold=2.0)
                wc3 = count_word_clusters(xs, gap_threshold=3.0)
                api = api_wc.get(idx, '?')
                flag = '✓' if wc2 == api else f'API={api}'
                print(f"  L{idx:2d} (Y={cl['center_y']:6.2f}): {len(cl['points']):4d}glyph  "
                      f"wc@2={wc2:3d}  wc@3={wc3:3d}  [{flag}]")


if __name__ == '__main__':
    main()
