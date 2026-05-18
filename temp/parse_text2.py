"""
Parse main text path with correct Y tolerance to get 15 text lines.
Use tolerance ~13 units (half of 26.7 line spacing).
"""
import re

def parse_path_movetos_fast(d_str):
    """Fast extraction of m/M coordinates using regex, with position tracking."""
    positions = []
    cx, cy = 0.0, 0.0
    
    # Simple approach: find each command with its numbers
    # Split by commands, then process
    segments = re.split(r'([MmCcLlHhVvSsQqTtAaZz])', d_str)
    
    cur_cmd = None
    for seg in segments:
        seg = seg.strip()
        if not seg:
            continue
        if len(seg) == 1 and seg.isalpha():
            cur_cmd = seg
            continue
        
        # Parse numbers from segment
        nums = [float(n) for n in re.findall(r'[-+]?\d*\.?\d+(?:[eE][+-]?\d+)?', seg)]
        if not nums:
            continue
        
        if cur_cmd == 'M':
            for i in range(0, len(nums)-1, 2):
                cx, cy = nums[i], nums[i+1]
                positions.append((cx, cy))
            cur_cmd = 'L'  # implicit lineto
        elif cur_cmd == 'm':
            for k, i in enumerate(range(0, len(nums)-1, 2)):
                cx += nums[i]; cy += nums[i+1]
                positions.append((cx, cy))
            cur_cmd = 'l'  # implicit lineto
        elif cur_cmd == 'L':
            for i in range(0, len(nums)-1, 2):
                cx, cy = nums[i], nums[i+1]
        elif cur_cmd == 'l':
            for i in range(0, len(nums)-1, 2):
                cx += nums[i]; cy += nums[i+1]
        elif cur_cmd == 'H':
            for n in nums: cx = n
        elif cur_cmd == 'h':
            for n in nums: cx += n
        elif cur_cmd == 'V':
            for n in nums: cy = n
        elif cur_cmd == 'v':
            for n in nums: cy += n
        elif cur_cmd == 'C':
            for i in range(0, len(nums)-5, 6):
                cx, cy = nums[i+4], nums[i+5]
        elif cur_cmd == 'c':
            for i in range(0, len(nums)-5, 6):
                cx += nums[i+4]; cy += nums[i+5]
        elif cur_cmd == 'S':
            for i in range(0, len(nums)-3, 4):
                cx, cy = nums[i+2], nums[i+3]
        elif cur_cmd == 's':
            for i in range(0, len(nums)-3, 4):
                cx += nums[i+2]; cy += nums[i+3]
        elif cur_cmd == 'Q':
            for i in range(0, len(nums)-3, 4):
                cx, cy = nums[i+2], nums[i+3]
        elif cur_cmd == 'q':
            for i in range(0, len(nums)-3, 4):
                cx += nums[i+2]; cy += nums[i+3]
    
    return positions


def cluster_by_y_greedy(positions, tolerance=13.0):
    """Group positions into lines using greedy nearest-cluster approach."""
    lines = {}  # representative_y -> list of positions
    for x, y in positions:
        best_key = None
        best_dist = float('inf')
        for ly in lines:
            dist = abs(y - ly)
            if dist <= tolerance and dist < best_dist:
                best_dist = dist
                best_key = ly
        if best_key is None:
            lines[y] = [(x, y)]
        else:
            lines[best_key].append((x, y))
    return lines


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
    content = open('page10.svgz', encoding='utf-8').read()
    
    # Get all paths
    tag_starts = [m.start() for m in re.finditer('<path', content)]
    path_data_list = []
    for start in tag_starts:
        end = content.find('>', start)
        tag_str = content[start:end+1]
        d_match = re.search(r'\bd="([^"]*)"', tag_str)
        d = d_match.group(1) if d_match else ''
        path_data_list.append(len(d), d)
    
    # Get main text path (largest)
    path_data_list.sort(key=lambda x: -x[0])
    main_d = path_data_list[0][1]
    print(f"Main path len: {len(main_d)}")
    
    print("Parsing...")
    positions = parse_path_movetos_fast(main_d)
    print(f"Positions: {len(positions)}")
    print(f"Y range: {min(p[1] for p in positions):.1f} to {max(p[1] for p in positions):.1f}")
    
    # Try different tolerances
    for tol in [10, 12, 13, 14, 15]:
        lines = cluster_by_y_greedy(positions, tolerance=tol)
        sorted_lines = sorted(lines.items())
        print(f"\n=== Tolerance={tol} → {len(sorted_lines)} clusters ===")
        if 10 <= len(sorted_lines) <= 25:
            # API word counts for page 10
            api_wc = [7,9,10,9,12,9,11,11,11,12,12,14,9,11,8]
            for i, (y, pts) in enumerate(sorted_lines):
                xs = [p[0] for p in pts]
                wc = count_word_clusters(xs, gap_threshold=2.0)
                api = api_wc[i] if i < len(api_wc) else '?'
                flag = '✓' if wc == api else f'API={api}'
                print(f"  Line {i+1:2d} (Y={y:6.2f}): {len(pts):4d} glyphs, {wc:3d} word-clust [{flag}]")


if __name__ == '__main__':
    main()
