#!/usr/bin/env bash
# Shell sets — only one runs at a time:
#   waybar     Waybar + swaync (swaync.service, started and stopped via systemd, never masked)
#   ajmashell  Quickshell config ~/.config/quickshell/ajmashell
# The default set for autostart is `shell` in configs/vars.lua.
#
# Usage:
#   shellset.sh start <waybar|ajmashell>  stop the other set, start this one (autostart)
#   shellset.sh toggle                    switch to the other set
#   shellset.sh restart                   restart the active set
#   shellset.sh hide                      hide/show the bar of the active set
#   shellset.sh active                    print the active set
#
# Tests: ~/Projects/hyprland-lua-migration/tools/test-shellset.sh

set -u

QS_CONFIG=ajmashell
WBRESTART="${SHELLSET_WBRESTART:-$HOME/.config/hypr/scripts/wbrestart.sh}"

active() {
    if qs list -c "$QS_CONFIG" -j 2>/dev/null | grep -q '"pid"'; then
        echo ajmashell
    else
        echo waybar
    fi
}

start_waybar() {
    # swaync started outside systemd (wbrestart.sh) holds the D-Bus name, the service would fail
    pgrep -x swaync >/dev/null || systemctl --user start swaync.service
    pgrep -x waybar >/dev/null || setsid -f waybar >/dev/null 2>&1
}

stop_waybar() {
    pkill -x waybar
    # Waybar's notification module leaves `swaync-client -swb` subscribers behind;
    # they would re-activate swaync over D-Bus.
    pkill -f '^swaync-client -swb'
    systemctl --user stop swaync.service
    pkill -x swaync # wbrestart.sh starts swaync outside systemd
}

start_ajmashell() {
    qs -c "$QS_CONFIG" -n -d >/dev/null 2>&1
}

stop_ajmashell() {
    qs kill -c "$QS_CONFIG" >/dev/null 2>&1
    # `-n` in start_ajmashell exits if the old instance is still alive
    local i
    for ((i = 0; i < 30; i++)); do
        [[ "$(active)" == ajmashell ]] || return 0
        sleep 0.1
    done
    echo "shellset: ajmashell still running after qs kill" >&2
    return 1
}

case "${1:-}" in
    start)
        case "${2:-}" in
            waybar) stop_ajmashell; start_waybar ;;
            ajmashell) stop_waybar; start_ajmashell ;;
            *) echo "shellset: unknown set '${2:-}' (waybar|ajmashell)" >&2; exit 2 ;;
        esac
        ;;
    toggle)
        if [[ "$(active)" == ajmashell ]]; then
            stop_ajmashell && start_waybar
        else
            stop_waybar; start_ajmashell
        fi
        ;;
    restart)
        if [[ "$(active)" == ajmashell ]]; then
            stop_ajmashell && start_ajmashell
        else
            "$WBRESTART"
        fi
        ;;
    hide)
        if [[ "$(active)" == ajmashell ]]; then
            qs -c "$QS_CONFIG" ipc call bar toggle
        else
            pkill -SIGUSR1 -x waybar
        fi
        ;;
    active) active ;;
    *) sed -n '2,13s/^# \{0,1\}//p' "$0" >&2; exit 2 ;;
esac
