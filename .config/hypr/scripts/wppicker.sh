#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"
THUMB_DIR="$HOME/.cache/wppicker/thumbs"

mkdir -p "$THUMB_DIR"

cd "$WALLPAPER_DIR" || exit 1
IFS=$'\n'

# Remove thumbnails with no corresponding wallpaper
shopt -s nullglob
for thumb in "$THUMB_DIR"/*.png; do
    base=$(basename "$thumb" .png)
    found=0
    for ext in jpg png gif jpeg; do
        [ -f "$WALLPAPER_DIR/$base.$ext" ] && found=1 && break
    done
    [ "$found" -eq 0 ] && rm -f "$thumb"
done
shopt -u nullglob

# Generate missing thumbnails (slow on first run, instant after)
for a in $(ls -t *.jpg *.png *.gif *.jpeg 2>/dev/null); do
    base="${a%.*}"
    [ -f "$THUMB_DIR/$base.png" ] || magick "$WALLPAPER_DIR/$a" -resize x160 "$THUMB_DIR/$base.png"
done

SELECTED_WALL=$(for a in $(ls -t *.jpg *.png *.gif *.jpeg 2>/dev/null); do
    base="${a%.*}"
    echo -en "$a\0icon\x1f$THUMB_DIR/$base.png\n"
done | rofi -dmenu -theme ~/.config/rofi/wallpaper.rasi -p "Wallpaper")

[ -z "$SELECTED_WALL" ] && exit 1
SELECTED_PATH="$WALLPAPER_DIR/$SELECTED_WALL"

matugen image "$SELECTED_PATH"
swaync-client -rs

mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"
magick "$SELECTED_PATH" -resize x800 "$HOME/.config/hypr/rofi_wallpaper.bmp"

hyprctl hyprpaper wallpaper ", $SELECTED_PATH, cover"
