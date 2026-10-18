#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Brightness keys (brightnessctl): change the backlight, then show Ajmashell's OSD (ticket 15).
# Ticket 23: the notify-send fallback for Waybar + swaync and its swaync icons are gone.

step=10  # INCREASE/DECREASE BY THIS VALUE

# show_osd (Ajmashell OSD over IPC)
source "$(dirname "${BASH_SOURCE[0]}")/osd.sh"

get_backlight() {
	brightnessctl -m | cut -d, -f4 | sed 's/%//'
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

	brightnessctl set "${new_brightness}%"
	show_osd brightness "$new_brightness"
}

case "$1" in
	"--inc") change_backlight "$step" ;;
	"--dec") change_backlight "-$step" ;;
	*) get_backlight ;;
esac
