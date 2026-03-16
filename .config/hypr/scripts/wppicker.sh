#!/bin/bash

# === CONFIGURATION ===
# Directory where your wallpapers are stored
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
# Path to the symlink used by other parts of the system
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"

# Custom animation timing (Cubic Bezier)
# Format: p1,p2,p3,p4
# This one is very fast at the start and smooth at the end
BEZIER="0.1, 1, 0, 1"

# List of available anchor points for the 'grow' transition
POSITIONS=("center" "top" "left" "right" "bottom" "top-left" "top-right" "bottom-left" "bottom-right")
# Select a random position from the array
RANDOM_POS=${POSITIONS[$RANDOM % ${#POSITIONS[@]}]}

# Ensure the swww-daemon is running
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon &
    sleep 1
fi

cd "$WALLPAPER_DIR" || exit 1
# Handle filenames with spaces correctly
IFS=$'\n'

# === WALLPAPER SELECTION (ROFI) ===
# Generates a list with icons, sorted by newest file first
SELECTED_WALL=$(for a in $(ls -t *.jpg *.png *.gif *.jpeg 2>/dev/null); do echo -en "$a\0icon\x1f$a\n"; done | rofi -dmenu -theme ~/.config/rofi/wallpaper.rasi -p "Wallpaper")

# Exit if no wallpaper was selected (e.g., pressed Esc)
[ -z "$SELECTED_WALL" ] && exit 1
SELECTED_PATH="$WALLPAPER_DIR/$SELECTED_WALL"

# === CORE WORKFLOW ===

# 1. Generate color palette and update system configs via Matugen
matugen image "$SELECTED_PATH"

# 2. Apply wallpaper with randomized 'grow' animation
# Note: --transition-fps is set to 144. Adjust if your monitor Hz is different.
swww img "$SELECTED_PATH" \
    --transition-fps 60 \
    --transition-type outer \
    --transition-duration 1.5 \
    --transition-bezier "$BEZIER" \
    --transition-step 2 \
    --transition-pos "$RANDOM_POS"

# 3. Update the symlink for persistence
mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"
