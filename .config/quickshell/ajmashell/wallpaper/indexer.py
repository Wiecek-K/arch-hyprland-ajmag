#!/usr/bin/env python3
# Wallpaper indexer for the carousel (ticket 19): colour bucket + thumbnail per wallpaper, cached in
# ~/.cache/ajmashell/wallpapers/index.json and recomputed only for new or changed files (mtime, size).
# Adapted from serpantinum src/scripts/wallpaper/indexer.py:
# https://github.com/ilyamiro/serpantinum@c34fb827147ddbd9429ab84524d40c22fe16769a
# Copyright (C) 2026 Illia Miroshnichenko — AGPL-3.0-or-later
# Changes: the colour is matugen's dark `primary` (the accent the whole system gets after choosing
# the wallpaper; user, 2026-10-01) instead of the 1×1 px average, computed from the thumbnail, with its seed
# for wpapply.sh; same matugen flags as wpapply.sh;
# thumbnails made here (magick), so the carousel never decodes full-size images; no videos, no posters,
# no per-directory hash dirs; Python standard library only (Pillow is not installed).
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Usage: indexer.py [wallpaper_dir] [cache_dir]   prints the index JSON on stdout
# Tests: ~/Projects/hyprland-lua-migration/tools/test-wallpaper-indexer.py

import colorsys
import fcntl
import hashlib
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
# Same flags as ~/.config/hypr/scripts/wpapply.sh, so the bucket matches the colour actually applied
MATUGEN = ["matugen", "image", "--dry-run", "-q", "-j", "hex", "--source-color-index", "0"]
THUMB_HEIGHT = 540
FALLBACK = "#808080"

# Hue ranges in degrees, from serpantinum get_color_bucket(); Red wraps around 0°.
# Orange (15–45°) and Yellow (45–75°) merged into Amber, Green from 63° instead of 75° (user, 2026-10-01: the
# muted orange primaries look brown; olive primaries at 66–73° are green; no wallpaper between 55° and 66°,
# pure yellow #ffff00 is 60°). Purple from 231° instead of 260° (user, 2026-10-01: lavender primaries at
# 233–238° are purple; the bluest of them, 229°, stays blue). Red up to 24° instead of 15° and Blue from 158°
# instead of 165° (user, 2026-10-01: salmon 16–22° is red, mint 164° is blue; gaps 22–26° and 153–164°).
HUE_BUCKETS = [
    (24, 63, "Amber"),
    (63, 158, "Green"),
    (158, 231, "Blue"),
    (231, 315, "Purple"),
    (315, 345, "Pink"),
]


def color_bucket(hex_str):
    """Bucket name for a #rrggbb colour (serpantinum thresholds)."""
    try:
        h = str(hex_str).strip().lstrip("#")[:6]
        r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    except (ValueError, TypeError):
        return "Monochrome"
    hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
    if sat < 0.05 or val < 0.08:
        return "Monochrome"
    deg = hue * 360.0
    for lo, hi, name in HUE_BUCKETS:
        if lo <= deg < hi:
            return name
    return "Red"


def scheme_colors(path):
    """(primary, seed): the bucket colour and matugen's source colour picked from the image.
    wpapply.sh feeds the seed to `matugen color hex`, which gives the same scheme without decoding the image."""
    try:
        out = subprocess.check_output(MATUGEN + [path], stderr=subprocess.DEVNULL, timeout=30)
        colors = json.loads(out)["colors"]
        return colors["primary"]["dark"]["color"].lower(), colors["source_color"]["dark"]["color"].lower()
    except (subprocess.SubprocessError, OSError, ValueError, KeyError):
        return FALLBACK, None


def make_thumb(path, thumb):
    if os.path.exists(thumb):
        return True
    tmp = thumb + ".tmp.jpg"
    try:
        subprocess.run(["magick", path + "[0]", "-resize", f"x{THUMB_HEIGHT}", "-quality", "85", tmp],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=30)
        os.replace(tmp, thumb)
        return True
    except (subprocess.SubprocessError, OSError):
        return False


def thumb_path(thumb_dir, path, mtime, size):
    key = hashlib.sha256(f"{path}:{mtime}:{size}".encode()).hexdigest()[:16]
    return os.path.join(thumb_dir, key + ".jpg")


def process(entry, thumb_dir, cached):
    name, path, mtime, size = entry
    old = cached.get(name)
    thumb = thumb_path(thumb_dir, path, mtime, size)
    if (old and old.get("mtime") == mtime and old.get("size") == size and old.get("seed")
            and old.get("colorsFrom") in ("thumb", "image") and os.path.exists(old.get("thumb", ""))):
        return {**old, "bucket": color_bucket(old.get("primary"))}  # the buckets may have changed since
    thumb = thumb if make_thumb(path, thumb) else path
    # Colours from the thumbnail, not the full image (user, 2026-10-01): 0.1 s and ~14 MB instead of up to
    # 2.3 s and 320 MB per wallpaper; on most wallpapers the primary moves by 1–5 RGB units, and on the few
    # where the dominant colour flips the user prefers the thumbnail's.
    primary, seed = scheme_colors(thumb)
    return {
        "fileName": name,
        "path": path,
        "thumb": thumb,
        "colorsFrom": "thumb" if thumb != path else "image",
        "primary": primary,
        "seed": seed,
        "bucket": color_bucket(primary),
        "mtime": mtime,
        "size": size,
    }


def scan(src_dir):
    entries = []
    try:
        dir_entries = list(os.scandir(src_dir))
    except OSError:
        return entries
    for e in dir_entries:
        try:
            if not e.is_file() or os.path.splitext(e.name)[1].lower() not in IMAGE_EXTS:
                continue
            st = e.stat()
        except OSError:
            continue
        entries.append((e.name, os.path.abspath(e.path), int(st.st_mtime), int(st.st_size)))
    return entries


def run(src_dir, cache_dir):
    thumb_dir = os.path.join(cache_dir, "thumbs")
    os.makedirs(thumb_dir, exist_ok=True)
    index_file = os.path.join(cache_dir, "index.json")

    cached = {}
    try:
        with open(index_file) as f:
            for item in json.load(f).get("items", []):
                cached[item["fileName"]] = item
    except (OSError, ValueError, KeyError):
        pass

    entries = scan(src_dir)
    # matugen is ~0.5 s CPU per image; leave cores for the desktop on the first run
    workers = max(2, (os.cpu_count() or 4) // 2)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        items = list(pool.map(lambda e: process(e, thumb_dir, cached), entries))
    items.sort(key=lambda i: i["fileName"])

    # thumbnails of removed or changed wallpapers
    keep = {os.path.basename(i["thumb"]) for i in items}
    for t in os.listdir(thumb_dir):
        if t not in keep:
            try:
                os.remove(os.path.join(thumb_dir, t))
            except OSError:
                pass

    data = {"srcDir": os.path.abspath(src_dir), "updatedAt": int(time.time()), "items": items}
    tmp = index_file + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, index_file)
    return data


def main():
    home = os.path.expanduser("~")
    src_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(home, "Pictures/wallpapers")
    cache_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(home, ".cache/ajmashell/wallpapers")
    os.makedirs(cache_dir, exist_ok=True)
    # one indexer at a time; a second call waits and then finds everything cached
    with open(os.path.join(cache_dir, "indexer.lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = run(src_dir, cache_dir)
    sys.stdout.write(json.dumps(data))


if __name__ == "__main__":
    main()
