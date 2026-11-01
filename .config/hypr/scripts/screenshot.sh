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

# One screenshot at a time: a second press would start its slurp over the first run's frozen layer, before its own
# freeze, and two selections would run at once.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/ajmashell-screenshot.lock"
flock -n 9 || exit 0

# Picture of every monitor before anything shows (ticket c04, faza C). slurp's overlay takes the pointer, so the app
# under it got "pointer leave" and hid its hover (menu, tooltip) before grim took the picture. grim -c keeps the cursor
# on the picture (user's request 2026-11-01); ppm = no compression, a few tens of ms per monitor.
SNAP_DIR="${XDG_RUNTIME_DIR:-/tmp}/ajmashell-screenshot"
mkdir -p "$SNAP_DIR"
MONITORS=$(hyprctl monitors -j)
for name in $(jq -r '.[].name' <<<"$MONITORS"); do
    grim -c -t ppm -o "$name" "$SNAP_DIR/$name.ppm"
done

# Then freeze the screen, so the selection is made on what will be on the screenshot. hyprpicker -r -z shows a frozen
# copy of every monitor (no zoom lens; its -c gives no cursor here, checked 2026-11-01).
# Idea from hyprshot --freeze (github.com/Gustash/Hyprshot, GPL-3.0); own implementation, see pochodzenie-komponentow.md.
FREEZE_PID=""
unfreeze() {
    [ -n "$FREEZE_PID" ] || return 0
    kill "$FREEZE_PID" 2>/dev/null
    wait "$FREEZE_PID" 2>/dev/null
    FREEZE_PID=""
}
trap 'unfreeze; rm -rf "$SNAP_DIR"' EXIT
hyprpicker -r -z >/dev/null 2>&1 9>&- &
FREEZE_PID=$!
# slurp must map above the frozen layer: started earlier, it would take the pointer before hyprpicker copies the screen.
# The layer shows after ~0.1 s; give up after 1 s and select on the live screen (the cut still comes from the pictures).
for _ in $(seq 40); do
    hyprctl layers -j | jq -e 'any(.. | objects | .namespace? ; . == "hyprpicker")' >/dev/null && break
    sleep 0.025
done

GEOM=$(slurp -b "$SLURP_BG" -c "$SLURP_BORDER" -s "$SLURP_FILL" -w 3)

if [ -z "$GEOM" ]; then
    exit 1
fi

# slurp prints "X,Y WxH" in layout coordinates. The monitor that holds the top-left corner gives satty's spot and the
# picture to cut from (width/height in pixels, x/y in layout coordinates, hence * scale); the focused monitor only as a
# fallback. CROP is empty when the selection reaches past that monitor.
read -r MON_NAME MON_X MON_Y CROP < <(jq -r --arg g "$GEOM" '
    ($g | capture("^(?<x>-?[0-9]+),(?<y>-?[0-9]+) (?<w>[0-9]+)x(?<h>[0-9]+)$") | map_values(tonumber)) as $s
    | (map(select($s.x >= .x and $s.x < .x + .width / .scale and $s.y >= .y and $s.y < .y + .height / .scale))
       + map(select(.focused))) | first
    | (if $s.x + $s.w <= .x + .width / .scale and $s.y + $s.h <= .y + .height / .scale
       then "\($s.w * .scale | round)x\($s.h * .scale | round)+\(($s.x - .x) * .scale | round)+\(($s.y - .y) * .scale | round)"
       else "" end) as $crop
    | "\(.name) \(.x) \(.y) \($crop)"' <<<"$MONITORS")

LOCAL_X=$(( ${GEOM%%,*} - MON_X ))
LOCAL_Y=$(( $(cut -d',' -f2 <<<"${GEOM%% *}") - MON_Y ))

TMP_IMG="/tmp/satty_capture.png"
if [ -n "$CROP" ]; then
    magick "$SNAP_DIR/$MON_NAME.ppm" -crop "$CROP" +repage "$TMP_IMG"
else
    # Across two monitors: from the frozen screen, without the cursor.
    grim -g "$GEOM" "$TMP_IMG"
fi
unfreeze

# satty-logged.sh records runs and freezes in ~/.local/state/satty/satty.log
SATTY_CMD="$HOME/.config/hypr/scripts/satty-logged.sh --filename $TMP_IMG --early-exit --copy-command wl-copy --output-filename ~/Pictures/Screenshots/satty-$(date '+%Y%m%d-%H%M%S').png"
hyprctl dispatch "hl.dsp.exec_cmd([[$SATTY_CMD]], { float = true, move = { $LOCAL_X, $LOCAL_Y } })"
