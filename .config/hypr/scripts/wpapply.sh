#!/bin/bash
# Set a wallpaper and regenerate the colours: hyprpaper + current_wallpaper symlink, then matugen (templates:
# Hyprland borders, Ajmashell, kitty, …).
# Used by the Ajmashell wallpaper carousel (ticket 19, SUPER+W); the rofi picker went with the Waybar set (ticket 23).
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
# Palette flags (scheme, contrast, lightness) come from the Przepis palety (~/.config/matugen/przepis-palety.json,
# faza E) through palette_recipe.py, the same module the indexer uses, and so does the fallback's Seed-choice flag
# (most dominant Kandydat or a --prefer rule, ticket 03); the stored seed counts only when the entry was
# computed with the current recipe (its fingerprint), else the indexer redoes it first. Right after a recipe change
# that redoes every wallpaper (~3 s CPU-bound on 8 threads for ~106), unless the carousel's own indexer run, started
# when it opened, has already done it (one indexer at a time: this call waits for it and then finds the cache).
INDEX="$HOME/.cache/ajmashell/wallpapers/index.json"
INDEXER="$HOME/.config/quickshell/ajmashell/wallpaper/indexer.py"
RECIPE="$HOME/.config/quickshell/ajmashell/wallpaper/palette_recipe.py"
mapfile -t PALETTE < <(python3 "$RECIPE" flags palette)
mapfile -t SEED_RULE < <(python3 "$RECIPE" flags seed 2>/dev/null)
# never without a Seed flag (module failed to run): matugen would ask interactively and fail without a terminal
[[ ${#SEED_RULE[@]} -gt 0 ]] || SEED_RULE=(--source-color-index 0)
RECIPE_ID=$(python3 "$RECIPE" fingerprint 2>/dev/null)
MTIME=$(stat -c %Y "$SELECTED_PATH")
seed_from_index() {
    [ -f "$INDEX" ] && jq -r --arg p "$SELECTED_PATH" --argjson m "$MTIME" --arg r "$RECIPE_ID" \
        'first(.items[] | select(.path == $p and .mtime == $m and .recipe == $r) | .seed // empty) // empty' "$INDEX" 2>/dev/null
}
SEED=$(seed_from_index)
if [[ ! "$SEED" =~ ^#[0-9a-f]{6}$ && -f "$INDEXER" && "$(dirname "$SELECTED_PATH")" == "$HOME/Pictures/wallpapers" ]]; then
    python3 "$INDEXER" >/dev/null 2>&1
    SEED=$(seed_from_index)
fi
if [[ "$SEED" =~ ^#[0-9a-f]{6}$ ]]; then
    matugen color hex "$SEED" "${PALETTE[@]}" --import-json-string "$(jq -cn --arg i "$SELECTED_PATH" '{image: $i}')"
else
    # matugen 4.x przy kilku kolorach źródłowych pyta interaktywnie (bez terminala = błąd), więc reguła wyboru Seeda
    # z Przepisu (zawsze dokładnie jedna flaga; startowo --source-color-index 0 = najbardziej dominujący, jak w 3.0).
    # The carousel indexer (~/.config/quickshell/ajmashell/wallpaper/indexer.py) uses the same flags for its colour buckets.
    matugen image "${SEED_RULE[@]}" "${PALETTE[@]}" "$SELECTED_PATH"
fi
