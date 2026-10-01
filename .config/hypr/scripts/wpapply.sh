#!/bin/bash
# Set a wallpaper and regenerate the colours: matugen (templates: Hyprland borders, Ajmashell, Waybar, …),
# swaync reload, current_wallpaper symlink, rofi launcher image, hyprpaper.
# Used by wppicker.sh (rofi, Waybar set) and the Ajmashell wallpaper carousel (ticket 19).
# Usage: wpapply.sh /path/to/wallpaper

SELECTED_PATH="$1"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"
[ -f "$SELECTED_PATH" ] || { echo "wpapply: no such file: $SELECTED_PATH" >&2; exit 1; }

# matugen 4.x przy kilku kolorach źródłowych pyta interaktywnie (bez terminala = błąd); 0 = najbardziej dominujący, jak domyślnie w 3.0
# The carousel indexer (~/.config/quickshell/ajmashell/wallpaper/indexer.py) uses the same flags for its colour buckets.
matugen image --source-color-index 0 "$SELECTED_PATH"
pgrep -x swaync >/dev/null && swaync-client -rs

mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"
magick "$SELECTED_PATH" -resize x800 "$HOME/.config/hypr/rofi_wallpaper.bmp"

hyprctl hyprpaper wallpaper ", $SELECTED_PATH, cover"
