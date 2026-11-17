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

MONITORS=$(hyprctl monitors -j)

# Freeze the screen before anything shows (ticket c04, faza C): slurp's overlay takes the pointer, so the app under it
# got "pointer leave" and hid its hover (menu, tooltip) before grim took the picture. The selection is made on the frozen
# copy, and the picture is grim of that copy. hyprpicker -r -z shows a frozen copy of every monitor (no zoom lens) without
# the cursor (its -c gives no cursor here, checked 2026-11-01), and grim without -c adds none: never a cursor on the
# picture (ticket c27, user 2026-11-05: the cursor "more in the way than helpful").
# Idea from hyprshot --freeze (github.com/Gustash/Hyprshot, GPL-3.0); own implementation, see pochodzenie-komponentow.md.
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
# The layer shows after ~0.1 s; give up after 1 s and select on the live screen (the hover may be gone then).
for _ in $(seq 40); do
    hyprctl layers -j | jq -e 'any(.. | objects | .namespace? ; . == "hyprpicker")' >/dev/null && break
    sleep 0.025
done

GEOM=$(slurp -b "$SLURP_BG" -c "$SLURP_BORDER" -s "$SLURP_FILL" -w 3)

if [ -z "$GEOM" ]; then
    exit 1
fi

# slurp prints "X,Y WxH" in layout coordinates. The monitor that holds the top-left corner (width/height in pixels, x/y in
# layout coordinates, hence / scale; the focused monitor only as a fallback) gives satty's spot on that monitor and the
# picture's scale: grim's default is the highest scale of all outputs, so next to a scale-1.5 laptop panel a selection on
# a scale-1 monitor came out 1.5x larger (code review, ticket c27).
read -r LOCAL_X LOCAL_Y MON_SCALE < <(jq -r --arg g "$GEOM" '
    ($g | capture("^(?<x>-?[0-9]+),(?<y>-?[0-9]+)") | map_values(tonumber)) as $s
    | (map(select($s.x >= .x and $s.x < .x + .width / .scale and $s.y >= .y and $s.y < .y + .height / .scale))
       + map(select(.focused))) | first
    | "\($s.x - .x) \($s.y - .y) \(.scale)"' <<<"$MONITORS")

TMP_IMG="/tmp/satty_capture.png"
grim -s "$MON_SCALE" -g "$GEOM" "$TMP_IMG"
unfreeze

# Frame in $primary around the picture (ticket c24, faza C, user 2026-11-12: "dorysuj ramkę"). The frame users liked
# was slurp's border caught by grim while slurp faded out; that race is gone (layer rule slurp-no-anim), so the frame is
# drawn here on purpose: 2 logical px x the monitor scale, outside the picture so it hides no content.
FRAME_PX=$(awk -v s="$MON_SCALE" 'BEGIN { printf "%d", 2 * s + 0.5 }')
magick "$TMP_IMG" -bordercolor "#$PRIMARY" -border "$FRAME_PX" "$TMP_IMG"

# satty's Save does not create the directory ("Error while saving file: No such file or directory", ticket 23 faza C),
# so make it here. Pictures folder from xdg-user-dir; without the command or a PICTURES entry it prints nothing or the
# home directory, then ~/Pictures.
PICTURES_DIR=$(xdg-user-dir PICTURES 2>/dev/null)
if [ -z "$PICTURES_DIR" ] || [ "${PICTURES_DIR%/}" = "$HOME" ]; then
    PICTURES_DIR="$HOME/Pictures"
fi
SHOT_DIR="$PICTURES_DIR/Screenshots"
mkdir -p "$SHOT_DIR"

# satty runs directly. Until ticket 21 (faza C) it ran through satty-logged.sh, a log for the freeze on the old laptop's
# NVIDIA driver (known issue 01 in the migration project); 131 runs on the desktop without a freeze, so the log went.
# On a freeze with NVIDIA again: restore satty-logged.sh from the dotfiles history (tag ticket-c21-start).
# exec_cmd runs the command through a shell: %q keeps a path with spaces as one argument.
SATTY_CMD="satty --filename $TMP_IMG --early-exit --copy-command wl-copy --output-filename $(printf '%q' "$SHOT_DIR/satty-$(date '+%Y%m%d-%H%M%S').png")"
hyprctl dispatch "hl.dsp.exec_cmd([[$SATTY_CMD]], { float = true, move = { $LOCAL_X, $LOCAL_Y } })"
