#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Volume keys: change the output volume, then show Ajmashell's OSD (ticket 15).
# Ticket 23: the notify-send fallback for Waybar + swaync, its swaync icons and the unbound mic actions are gone.

# show_osd (Ajmashell OSD over IPC)
source "$(dirname "${BASH_SOURCE[0]}")/osd.sh"

get_volume() {
    volume=$(pamixer --get-volume)
    if [[ "$volume" -eq "0" ]]; then
        echo "Muted"
    else
        echo "$volume %"
    fi
}

inc_volume() {
    if [ "$(pamixer --get-mute)" == "true" ]; then
        toggle_mute
    else
        pamixer -i 5 --allow-boost --set-limit 150 && show_osd volume
    fi
}

dec_volume() {
    if [ "$(pamixer --get-mute)" == "true" ]; then
        toggle_mute
    else
        pamixer -d 5 && show_osd volume
    fi
}

toggle_mute() {
    if [ "$(pamixer --get-mute)" == "false" ]; then
        pamixer -m
    else
        pamixer -u
    fi && show_osd volume
}

case "$1" in
    --inc) inc_volume ;;
    --dec) dec_volume ;;
    --toggle) toggle_mute ;;
    *) get_volume ;;
esac
