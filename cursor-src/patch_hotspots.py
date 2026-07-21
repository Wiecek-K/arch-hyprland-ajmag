#!/usr/bin/env python3
"""
Patch hyprcursor .hlc archives with corrected hotspot values.

Corrections derived from:
- Browser click-offset test (cursor-hotspot-test.html) at render size 36
- Formula: new_x = current_x - dx/36, new_y = current_y - dy/36
- SVG canvas is 32x32, no padding unlike source PNGs (which had ~4px shadow padding)
- Cursors with hotspot > 1.0 had source .cursor hx/hy outside image bounds (shadow area)
"""

import zipfile, os, io, re, shutil, tempfile

THEME = os.path.expanduser('~/.local/share/icons/Vimix-hyprcursor/hyprcursors')
RENDER = 36  # HYPRCURSOR_SIZE

# (new_hx, new_hy) — all values in 0-1 normalized range
# Tested cursors: exact correction from click-offset test
# Untested center-based: apply avg (-8,-8) from 0.6667
# Broken > 1.0 cursors: fixed to near-edge (tip at edge minus ~2px / 36)
EDGE = 34 / RENDER   # near-edge tip for cursors that point to a corner/edge
NEAR = 2  / RENDER   # near-origin tip

CORRECTIONS = {
    # --- Tested: arrow family (original source hx=hy=0.1667 @ render 36) ---
    'default':      (2/RENDER, 1/RENDER),   # dx=+4, dy=+5
    'context-menu': (2/RENDER, 1/RENDER),
    'help':         (2/RENDER, 1/RENDER),
    'progress':     (2/RENDER, 2/RENDER),   # dx=+4, dy=+4
    'copy':         (2/RENDER, 3/RENDER),   # dx=+4, dy=+3
    'alias':        (3/RENDER, 4/RENDER),   # dx=+3, dy=+2
    'no-drop':      (3/RENDER, 4/RENDER),   # dx=+3, dy=+2

    # --- Tested: center family (original hx=hy=0.6667 @ render 36) ---
    'crosshair':     (16/RENDER, 17/RENDER), # dx=+8, dy=+7
    'cell':          (16/RENDER, 17/RENDER),
    'text':          (16/RENDER, 17/RENDER),
    'vertical-text': (16/RENDER, 17/RENDER),
    'all-scroll':    (16/RENDER, 16/RENDER), # dx=+8, dy=+8
    'not-allowed':   (16/RENDER, 16/RENDER),
    'dnd-move':      (16/RENDER, 16/RENDER), # covers grab/grabbing/move aliases
    'fleur':         (16/RENDER, 16/RENDER),

    # --- Tested: pointer (special layout hx=0.6667, hy=0.1667) ---
    'pointer': (15/RENDER, 3/RENDER),        # dx=+9, dy=+3

    # --- Untested center-based: same group as all-scroll ---
    'openhand':   (16/RENDER, 16/RENDER),
    'zoom-in':    (16/RENDER, 16/RENDER),
    'zoom-out':   (16/RENDER, 16/RENDER),
    'size_bdiag': (16/RENDER, 16/RENDER),
    'size_fdiag': (16/RENDER, 16/RENDER),
    'col-resize': (16/RENDER, 16/RENDER),
    'row-resize': (16/RENDER, 16/RENDER),
    'size_hor':   (16/RENDER, 16/RENDER),
    'size_ver':   (16/RENDER, 16/RENDER),
    'dnd-no-drop':(16/RENDER, 16/RENDER),

    # --- Corner/side cursors: fix > 1.0 values ---
    # bottom_*: tip near bottom edge (34/36)
    'bottom_left_corner':  (NEAR, EDGE),
    'bottom_right_corner': (EDGE, EDGE),
    'bottom_side':         (16/RENDER, EDGE),  # was hx=0.6667, hy=1.1667
    # top_*: tip near top edge
    'top_left_corner':     (NEAR, NEAR),       # hx=0.2083 → refine to 2/36
    'top_right_corner':    (EDGE, NEAR),       # hx=1.0833 → fix
    'top_side':            (16/RENDER, NEAR),  # hx=0.6667, hy=0.1667 — correct, just refine
    # left/right sides
    'left_side':           (NEAR, 16/RENDER),  # hx=0.1667 ok, hy=0.6667 → center
    'right_side':          (EDGE, 16/RENDER),  # hx=1.1667 → fix
    # right-pointing arrows
    'right_ptr':           (EDGE, NEAR),       # hx=1.1667 → fix
    'center_ptr':          (16/RENDER, NEAR),  # up-pointing arrow, tip at top-center
    # color-picker: tip at bottom-left (eyedropper nib)
    'color-picker':        (NEAR, EDGE),       # hy=1.2083 → fix
}


def patch_hlc(name, new_hx, new_hy):
    hlc_path = os.path.join(THEME, f'{name}.hlc')
    if not os.path.exists(hlc_path):
        return f'SKIP (not found)'

    with zipfile.ZipFile(hlc_path, 'r') as zin:
        names = zin.namelist()
        files = {n: zin.read(n) for n in names}

    meta = files['meta.hl'].decode()
    old_hx = re.search(r'hotspot_x\s*=\s*([\d.]+)', meta)
    old_hy = re.search(r'hotspot_y\s*=\s*([\d.]+)', meta)
    old_vals = f"({old_hx.group(1) if old_hx else '?'}, {old_hy.group(1) if old_hy else '?'})"

    meta = re.sub(r'hotspot_x\s*=\s*[\d.]+', f'hotspot_x = {new_hx:.6f}', meta)
    meta = re.sub(r'hotspot_y\s*=\s*[\d.]+', f'hotspot_y = {new_hy:.6f}', meta)
    files['meta.hl'] = meta.encode()

    # Rewrite archive in-place (write to tmp then replace)
    tmp = hlc_path + '.tmp'
    with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as zout:
        for n in names:
            zout.writestr(n, files[n])
    os.replace(tmp, hlc_path)

    new_vals = f"({new_hx:.4f}, {new_hy:.4f})"
    return f'{old_vals} → {new_vals}'


print(f'Patching {len(CORRECTIONS)} cursor hotspots...\n')
for name, (hx, hy) in sorted(CORRECTIONS.items()):
    result = patch_hlc(name, hx, hy)
    px_x = round(hx * RENDER, 1)
    px_y = round(hy * RENDER, 1)
    print(f'  {name:<22} {result}  ({px_x}px, {px_y}px at render={RENDER})')

print('\nDone. Reload cursor:')
print('  hyprctl setcursor Vimix-hyprcursor 36')
