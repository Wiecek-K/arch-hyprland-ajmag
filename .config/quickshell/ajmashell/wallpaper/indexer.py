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
# no per-directory hash dirs; Python standard library only (Pillow is not installed); matugen's palette flags
# from the Przepis palety (palette_recipe.py, faza E ticket 02), and an entry made with another recipe is redone
# (Seed, primary, bucket; the thumbnail stays); the Seed-choice flag (most dominant Kandydat or a --prefer rule)
# from the Przepis palety too, instead of a fixed --source-color-index 0 (faza E ticket 03); an old-paper white
# primary (warm, OKLCH chroma below PAPER_CHROMA_MAX) goes to Gray instead of Amber (faza C ticket 18).
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

sys.dont_write_bytecode = True  # no __pycache__ in the shell config dir
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette_recipe  # noqa: E402

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
# Same flags as ~/.config/hypr/scripts/wpapply.sh, so the bucket matches the colour actually applied; the Seed-choice
# and palette flags are added from the Przepis palety
MATUGEN = ["matugen", "image", "--dry-run", "-q", "-j", "hex"]
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


# "Old paper" white: a warm primary with almost no colour goes to Gray instead of Amber (faza C ticket 18,
# user, 2026-11-08). The user's gray wallpapers are ink sketches on cream paper; matugen gives them a dirty-white
# primary (#c8c2b0, #e2dec3, #fef4e2: OKLCH chroma 0.026-0.036, hue in the Amber range). Chroma is OKLCH, not HSV
# saturation: HSV inflates the saturation of light colours (#fef4e2 is HSV s 0.11). Only Amber hues: cool near-whites
# with the same low chroma (#bec3d3, #c6d2d7) look blue to the user and stay in their hue bucket. Nearest beige
# that stays Amber: chroma 0.042 (#dabeaa, #d3c0a5). How to retune: docs/kategorie-tapet.md in hyprland-lua-migration.
PAPER_CHROMA_MAX = 0.04
PAPER_BUCKETS = {"Amber"}


def _rgb(hex_str):
    h = str(hex_str).strip().lstrip("#")[:6]
    if len(h) != 6:
        raise ValueError(hex_str)
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def oklch_chroma(hex_str):
    """OKLCH chroma of a #rrggbb colour (Björn Ottosson's OKLab, sRGB D65): 0 for grey, ~0.26 for pure red."""
    # sRGB to OKLab matrices copied from https://bottosson.github.io/posts/oklab/ (Björn Ottosson, public domain)
    r, g, b = (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in _rgb(hex_str))
    l_ = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m_ = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s_ = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    b2 = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    return (a * a + b2 * b2) ** 0.5


def hue_bucket(hex_str):
    """Bucket by HSV hue alone (serpantinum thresholds); Gray for grey, near-black and garbage."""
    try:
        r, g, b = _rgb(hex_str)
    except (ValueError, TypeError):
        return "Gray"
    hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
    if sat < 0.05 or val < 0.08:
        return "Gray"
    deg = hue * 360.0
    for lo, hi, name in HUE_BUCKETS:
        if lo <= deg < hi:
            return name
    return "Red"


def color_bucket(hex_str):
    """Bucket name for a #rrggbb colour: the hue bucket, except old-paper white goes to Gray."""
    name = hue_bucket(hex_str)
    if name in PAPER_BUCKETS and oklch_chroma(hex_str) < PAPER_CHROMA_MAX:
        return "Gray"
    return name


def scheme_colors(path, recipe_flags=()):
    """(primary, seed): the bucket colour and matugen's source colour picked from the image.
    wpapply.sh feeds the seed to `matugen color hex`, which gives the same scheme without decoding the image."""
    try:
        out = subprocess.check_output(MATUGEN + list(recipe_flags) + [path], stderr=subprocess.DEVNULL, timeout=30)
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


def process(entry, thumb_dir, cached, recipe):
    name, path, mtime, size = entry
    old = cached.get(name)
    thumb = thumb_path(thumb_dir, path, mtime, size)
    fingerprint = palette_recipe.fingerprint(recipe)
    if (old and old.get("mtime") == mtime and old.get("size") == size and old.get("seed")
            and old.get("recipe") == fingerprint
            and old.get("colorsFrom") in ("thumb", "image") and os.path.exists(old.get("thumb", ""))):
        return {**old, "bucket": color_bucket(old.get("primary"))}  # the buckets may have changed since
    thumb = thumb if make_thumb(path, thumb) else path
    # Colours from the thumbnail, not the full image (user, 2026-10-01): 0.1 s and ~14 MB instead of up to
    # 2.3 s and 320 MB per wallpaper; on most wallpapers the primary moves by 1–5 RGB units, and on the few
    # where the dominant colour flips the user prefers the thumbnail's.
    primary, seed = scheme_colors(thumb, palette_recipe.seed_flags(recipe) + palette_recipe.palette_flags(recipe))
    return {
        "fileName": name,
        "path": path,
        "thumb": thumb,
        "colorsFrom": "thumb" if thumb != path else "image",
        "primary": primary,
        "seed": seed,
        "recipe": fingerprint,  # wpapply.sh takes the seed only when this matches the current recipe
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


def run(src_dir, cache_dir, recipe_file=None):
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

    recipe = palette_recipe.load(recipe_file)
    entries = scan(src_dir)
    # matugen is ~0.5 s CPU per image; leave cores for the desktop on the first run
    workers = max(2, (os.cpu_count() or 4) // 2)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        items = list(pool.map(lambda e: process(e, thumb_dir, cached, recipe), entries))
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
