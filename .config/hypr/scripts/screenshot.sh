#!/bin/bash

GEOM=$(slurp)

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