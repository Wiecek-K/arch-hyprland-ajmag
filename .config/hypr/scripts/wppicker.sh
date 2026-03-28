#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"

cd "$WALLPAPER_DIR" || exit 1
IFS=$'\n'

SELECTED_WALL=$(for a in $(ls -t *.jpg *.png *.gif *.jpeg 2>/dev/null); do echo -en "$a\0icon\x1f$a\n"; done | rofi -dmenu -theme ~/.config/rofi/wallpaper.rasi -p "Wallpaper")

[ -z "$SELECTED_WALL" ] && exit 1
SELECTED_PATH="$WALLPAPER_DIR/$SELECTED_WALL"

matugen image "$SELECTED_PATH"
swaync-client -rs

mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"

hyprctl hyprpaper wallpaper ", $SELECTED_PATH, cover"
