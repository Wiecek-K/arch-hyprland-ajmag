#!/bin/bash
# Set a wallpaper and regenerate the colours: hyprpaper + current_wallpaper symlink, then matugen (templates:
# Hyprland borders, Ajmashell, Waybar, …), swaync reload, rofi launcher image.
# Used by wppicker.sh (rofi, Waybar set) and the Ajmashell wallpaper carousel (ticket 19).
# Usage: wpapply.sh /path/to/wallpaper

SELECTED_PATH="$1"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"
[ -f "$SELECTED_PATH" ] || { echo "wpapply: no such file: $SELECTED_PATH" >&2; exit 1; }

# Wallpaper first: matugen with its post_hooks (spicetify ~1.9 s) takes ~2.2 s, so setting hyprpaper last
# made the carousel close and nothing happen for ~3 s. The colours now follow the wallpaper instead.
mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"
hyprctl hyprpaper wallpaper ", $SELECTED_PATH, cover"

# Colours from the seed the carousel indexer stored (~/.cache/ajmashell/wallpapers/index.json), computed there from
# the wallpaper's thumbnail (user, 2026-10-01). `matugen color hex` gives the same scheme as `matugen image` on that
# thumbnail in ~10 ms (checked 2026-10-01: all 13 template outputs byte-identical). Only when the entry matches the
# file (path + mtime); a wallpaper not indexed yet is indexed first (only new files are processed, ~0.5 s each), and
# only if that fails the colours come from the full image. {{image}} (Hyprland templates) comes via --import-json-string.
INDEX="$HOME/.cache/ajmashell/wallpapers/index.json"
INDEXER="$HOME/.config/quickshell/ajmashell/wallpaper/indexer.py"
MTIME=$(stat -c %Y "$SELECTED_PATH")
seed_from_index() {
    [ -f "$INDEX" ] && jq -r --arg p "$SELECTED_PATH" --argjson m "$MTIME" \
        'first(.items[] | select(.path == $p and .mtime == $m) | .seed // empty) // empty' "$INDEX" 2>/dev/null
}
SEED=$(seed_from_index)
if [[ ! "$SEED" =~ ^#[0-9a-f]{6}$ && -f "$INDEXER" && "$(dirname "$SELECTED_PATH")" == "$HOME/Pictures/wallpapers" ]]; then
    python3 "$INDEXER" >/dev/null 2>&1
    SEED=$(seed_from_index)
fi
if [[ "$SEED" =~ ^#[0-9a-f]{6}$ ]]; then
    matugen color hex "$SEED" --import-json-string "$(jq -cn --arg i "$SELECTED_PATH" '{image: $i}')"
else
    # matugen 4.x przy kilku kolorach źródłowych pyta interaktywnie (bez terminala = błąd); 0 = najbardziej dominujący, jak domyślnie w 3.0
    # The carousel indexer (~/.config/quickshell/ajmashell/wallpaper/indexer.py) uses the same flags for its colour buckets.
    matugen image --source-color-index 0 "$SELECTED_PATH"
fi
pgrep -x swaync >/dev/null && swaync-client -rs

# jpeg:size lets libjpeg decode big JPEGs at 1/2–1/8 scale (10000 px wallpaper: 3.8 s → 1.2 s CPU); no effect on PNG
magick -define jpeg:size=1600x1600 "$SELECTED_PATH" -resize x800 "$HOME/.config/hypr/rofi_wallpaper.bmp"
