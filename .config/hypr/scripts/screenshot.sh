#!/bin/bash

COLORS_CONF="$HOME/.config/hypr/colors.conf"

get_color() {
    grep -oP "^\\\$$1 = rgba\\(\\K[0-9a-f]+" "$COLORS_CONF" | head -1
}

PRIMARY=$(get_color "primary")
SURFACE=$(get_color "surface")

# slurp format: #RRGGBBAA
# border: $primary full opacity (matches col.active_border start color)
# fill:   $primary 12% alpha (subtle tint of selected area)
# bg:     $surface 50% alpha (dim outside selection)
SLURP_BORDER="#${PRIMARY}"
SLURP_FILL="#${PRIMARY%??}20"
SLURP_BG="#${SURFACE%??}80"

GEOM=$(slurp -b "$SLURP_BG" -c "$SLURP_BORDER" -s "$SLURP_FILL" -w 3)

if [ -z "$GEOM" ]; then
    exit 1
fi

X_COORD=$(echo "$GEOM" | cut -d',' -f1)
Y_COORD=$(echo "$GEOM" | cut -d',' -f2 | cut -d' ' -f1)

MON_X=$(hyprctl monitors -j | jq '.[] | select(.focused) | .x')
MON_Y=$(hyprctl monitors -j | jq '.[] | select(.focused) | .y')

LOCAL_X=$(( X_COORD - MON_X ))
LOCAL_Y=$(( Y_COORD - MON_Y ))

TMP_IMG="/tmp/satty_capture.png"
grim -g "$GEOM" "$TMP_IMG"

hyprctl dispatch exec "[float; move $LOCAL_X $LOCAL_Y] satty --filename $TMP_IMG --early-exit --copy-command wl-copy --output-filename ~/Pictures/Screenshots/satty-$(date '+%Y%m%d-%H%M%S').png"
