#!/bin/bash

# --- CONFIGURATION ---
INTERNAL_MONITOR="eDP-1"
# ---------------------

# Detect connected external monitor dynamically
# We look for a monitor that is NOT the internal one
EXTERNAL_MONITOR=$(hyprctl monitors all -j | jq -r '.[] | select(.name != "'"$INTERNAL_MONITOR"'") | .name' | head -n 1)

# Check if external monitor is actually connected
if [ -z "$EXTERNAL_MONITOR" ]; then
    notify-send -u critical "Monitor Error" "No external monitor detected!"
    exit 1
fi

# Menu Options
option1="💻 Laptop Only"
option2="🖥️ External Only ($EXTERNAL_MONITOR)"
option3="💻+🖥️ Extend (External Right)"
option4="🖥️+💻 Extend (External Left)"
option5="🪞 Mirror"

# Launch Rofi Menu
options="$option1\n$option2\n$option3\n$option4\n$option5"
choice=$(echo -e "$options" | rofi -dmenu -i -p "Monitor Setup")

case $choice in
    $option1)
        # Laptop Only
        hyprctl keyword monitor "$EXTERNAL_MONITOR, disable"
        hyprctl keyword monitor "$INTERNAL_MONITOR, 1920x1080@60, 0x0, 1"
        ;;
    $option2)
        # External Only
        hyprctl keyword monitor "$INTERNAL_MONITOR, disable"
        hyprctl keyword monitor "$EXTERNAL_MONITOR, preferred, 0x0, 1"
        ;;
    $option3)
        # Extend (External Right)
        hyprctl keyword monitor "$INTERNAL_MONITOR, 1920x1080@60, 0x0, 1"
        hyprctl keyword monitor "$EXTERNAL_MONITOR, preferred, 1920x0, 1"
        ;;
    $option4)
        # Extend (External Left)
        # We need to know external width to place laptop correctly, but auto is safer for generic script
        hyprctl keyword monitor "$EXTERNAL_MONITOR, preferred, 0x0, 1"
        hyprctl keyword monitor "$INTERNAL_MONITOR, 1920x1080@60, auto, 1"
        ;;
    $option5)
        # Mirror
        hyprctl keyword monitor "$INTERNAL_MONITOR, 1920x1080@60, 0x0, 1"
        hyprctl keyword monitor "$EXTERNAL_MONITOR, preferred, 0x0, 1, mirror, $INTERNAL_MONITOR"
        ;;
esac
