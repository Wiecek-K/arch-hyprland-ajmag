#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Brightness keys (brightnessctl): change the backlight, then show Ajmashell's OSD (ticket 15).
# Ticket 23: the notify-send fallback for Waybar + swaync and its swaync icons are gone.
# Ticket c20: only with an enabled built-in panel (eDP, LVDS, DSI) and a backlight device; otherwise exit quietly, no OSD.
# brightnessctl without --class picks the first device of any class, on the desktop the Wi-Fi LED (phy0-led).

step=10  # INCREASE/DECREASE BY THIS VALUE

# show_osd (Ajmashell OSD over IPC)
source "$(dirname "${BASH_SOURCE[0]}")/osd.sh"

# Hyprland lists enabled outputs only; output names change (DP-5 became DP-6), so match the type at the start only
panel_enabled() {
	hyprctl monitors -j 2>/dev/null |
		jq -e 'any(.[]; (.name | test("^(eDP|LVDS|DSI)-")) and (.disabled != true))' > /dev/null 2>&1
}

# the first backlight device by name, as the Centrum sterowania's slider (control.mjs backlightDevice)
device=$(brightnessctl --class=backlight -l -m 2>/dev/null | cut -d, -f1 | LC_ALL=C sort | head -n 1)
if [[ -z "$device" ]] || ! panel_enabled; then
	exit 0
fi

get_backlight() {
	brightnessctl --class=backlight -d "$device" -m | cut -d, -f4 | sed 's/%//'
}

change_backlight() {
	local new_brightness
	new_brightness=$(( $(get_backlight) + $1 ))

	# Ensure new brightness is within valid range
	if (( new_brightness < 5 )); then
		new_brightness=5
	elif (( new_brightness > 100 )); then
		new_brightness=100
	fi

	brightnessctl --class=backlight -d "$device" set "${new_brightness}%" > /dev/null
	show_osd brightness "$new_brightness"
}

case "$1" in
	"--inc") change_backlight "$step" ;;
	"--dec") change_backlight "-$step" ;;
	*) get_backlight ;;
esac
