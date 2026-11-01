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

# Freeze the screen before the selection (ticket c04, faza C). slurp's overlay takes the pointer, so the app under it
# got "pointer leave" and hid its hover (menu, tooltip) before grim took the picture. hyprpicker -r -z shows a frozen
# copy of every monitor (no zoom lens); slurp and grim then work on that picture, so the hover stays on the screenshot.
# Idea from hyprshot --freeze (github.com/Gustash/Hyprshot, GPL-3.0); own implementation, see pochodzenie-komponentow.md.
# One screenshot at a time: a second press would start its slurp over the first run's frozen layer, before its own
# freeze, and two selections would run at once.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/ajmashell-screenshot.lock"
flock -n 9 || exit 0

FREEZE_PID=""
unfreeze() {
    [ -n "$FREEZE_PID" ] || return 0
    kill "$FREEZE_PID" 2>/dev/null
    wait "$FREEZE_PID" 2>/dev/null
    FREEZE_PID=""
}
trap unfreeze EXIT
hyprpicker -r -z >/dev/null 2>&1 9>&- &
FREEZE_PID=$!
# slurp must map above the frozen layer: started earlier, it would take the pointer before hyprpicker copies the screen.
# The layer shows after ~0.1 s; give up after 1 s and take the screenshot without the freeze.
for _ in $(seq 40); do
    hyprctl layers -j | jq -e 'any(.. | objects | .namespace? ; . == "hyprpicker")' >/dev/null && break
    sleep 0.025
done

GEOM=$(slurp -b "$SLURP_BG" -c "$SLURP_BORDER" -s "$SLURP_FILL" -w 3)

if [ -z "$GEOM" ]; then
    exit 1
fi

X_COORD=$(echo "$GEOM" | cut -d',' -f1)
Y_COORD=$(echo "$GEOM" | cut -d',' -f2 | cut -d' ' -f1)

# satty opens at the selection on the monitor that holds its top-left corner (width/height in pixels, x/y in layout
# coordinates, hence / scale); the focused monitor only as a fallback.
read -r MON_X MON_Y < <(hyprctl monitors -j | jq -r --argjson x "$X_COORD" --argjson y "$Y_COORD" '
    (map(select($x >= .x and $x < .x + .width / .scale and $y >= .y and $y < .y + .height / .scale)) + map(select(.focused)))
    | first | "\(.x) \(.y)"')

LOCAL_X=$(( X_COORD - MON_X ))
LOCAL_Y=$(( Y_COORD - MON_Y ))

TMP_IMG="/tmp/satty_capture.png"
grim -g "$GEOM" "$TMP_IMG"
unfreeze

# satty-logged.sh records runs and freezes in ~/.local/state/satty/satty.log
SATTY_CMD="$HOME/.config/hypr/scripts/satty-logged.sh --filename $TMP_IMG --early-exit --copy-command wl-copy --output-filename ~/Pictures/Screenshots/satty-$(date '+%Y%m%d-%H%M%S').png"
hyprctl dispatch "hl.dsp.exec_cmd([[$SATTY_CMD]], { float = true, move = { $LOCAL_X, $LOCAL_Y } })"
