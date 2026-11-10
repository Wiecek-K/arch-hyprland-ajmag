#!/usr/bin/env bash
# Screen recording with sound (faza C ticket cb40), instead of OBS: SUPER+R starts recording the focused monitor to
# ~/Videos/nagranie_DATE.mp4 with the system sound (the default output's monitor, no microphone; no default output =
# no sound, never the default source, which may be the microphone), the next SUPER+R ends it; a click on the Bar's
# privacy dot runs `stop`. Replaces record_gif.sh (hardcoded laptop monitor).
# While recording, the state file holds "recorder pid<TAB>start (s since the epoch)<TAB>file"; Ajmashell reads it on
# start and on `qs -c ajmashell ipc call recording refresh` (singletons/recording) and shows the time in the dot.
# This run waits for the recorder, so the end (also a failure) always clears the state and sends a notification:
# a click shows the file in the file manager (only that; user, 2026-11-10). A state file whose recorder is gone
# (killed) is removed by the next `stop` or toggle, so a click on a stuck dot clears it.
# Encoding: VA-API on an amdgpu card (RX 6600 XT, /dev/dri/renderD129 next to the iGPU's renderD128, where VA-API
# fails), else wf-recorder's software default.
# Usage: screen-record.sh [toggle | stop]   (default toggle)
# Env (tests): SCREEN_RECORD_STATE = state dir, SCREEN_RECORD_SYSFS = /sys/class/drm
# Tests: ~/Projects/hyprland-lua-migration/tools/test-screen-record.sh
set -u

STATE_DIR="${SCREEN_RECORD_STATE:-${XDG_RUNTIME_DIR:-/tmp}/ajmashell}"
STATE_FILE="$STATE_DIR/screen-record"
LOG_FILE="$STATE_DIR/screen-record.log"
SYSFS="${SCREEN_RECORD_SYSFS:-/sys/class/drm}"
APP="Nagrywanie ekranu"

mkdir -p "$STATE_DIR"

tell_bar() { qs -c ajmashell ipc call recording refresh >/dev/null 2>&1; }
fail() { notify-send -a "$APP" -u critical "Nagrywanie nie powiodło się" "$1"; }

# pid of the running recorder, or nothing (no state, or a stale one: the recorder died with the session)
running_pid() {
    local pid
    pid="$(cut -f1 "$STATE_FILE" 2>/dev/null)"
    [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null && echo "$pid"
}

# the first render node of an amdgpu card, or nothing
vaapi_device() {
    local node
    for node in "$SYSFS"/renderD*; do
        grep -qx 'DRIVER=amdgpu' "$node/device/uevent" 2>/dev/null && { echo "/dev/dri/${node##*/}"; return; }
    done
}

# file:// URI with every byte outside [A-Za-z0-9/._~-] percent-encoded (UTF-8 bytes one by one)
file_uri() {
    local LC_ALL=C s="$1" out="" c i
    for ((i = 0; i < ${#s}; i++)); do
        c="${s:i:1}"
        if [[ "$c" =~ [A-Za-z0-9/._~-] ]]; then out+="$c"; else printf -v c '%%%02X' "'$c"; out+="$c"; fi
    done
    echo "file://$out"
}

finished() { # finished <file>: the notification; waits for a click
    local file="$1" action
    action="$(notify-send -a "$APP" -i video-x-generic -A "default=Pokaż w folderze" --wait \
        "Nagranie zapisane" "$file")"
    [[ "$action" == default ]] && gdbus call --session --dest org.freedesktop.FileManager1 \
        --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems \
        "['$(file_uri "$file")']" "" >/dev/null
}

start() {
    local monitor sink dir file device pid rc
    local -a args
    monitor="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')"
    [[ -n "$monitor" ]] || { fail "Brak monitora z fokusem."; return 1; }
    sink="$(pactl get-default-sink 2>/dev/null)"
    dir="$(xdg-user-dir VIDEOS 2>/dev/null)"
    [[ -n "$dir" && "$dir" != "$HOME" ]] || dir="$HOME/Videos"
    mkdir -p "$dir"
    file="$dir/nagranie_$(date +%Y-%m-%d_%H-%M-%S).mp4"

    args=(-y -o "$monitor")
    [[ -n "$sink" ]] && args+=("--audio=$sink.monitor")
    device="$(vaapi_device)"
    [[ -n "$device" ]] && args+=(-c h264_vaapi -d "$device")
    args+=(-f "$file")

    wf-recorder "${args[@]}" >"$LOG_FILE" 2>&1 9>&- & # 9>&-: the recorder must not hold the start lock
    pid=$!
    printf '%s\t%s\t%s\n' "$pid" "$(date +%s)" "$file" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    exec 9>&- # the state is there: the next toggle stops this recording
    tell_bar

    # the session ends or this run is killed: end the recording cleanly (the file stays playable)
    trap 'kill -INT "$pid" 2>/dev/null' INT TERM HUP
    while :; do
        wait "$pid"; rc=$?
        kill -0 "$pid" 2>/dev/null || break # a trapped signal ends `wait` early, the recorder still writing
    done
    trap - INT TERM HUP
    rm -f "$STATE_FILE"
    tell_bar

    if [[ "$rc" -eq 0 && -s "$file" ]]; then
        finished "$file"
    else
        fail "$(tail -n 3 "$LOG_FILE" 2>/dev/null)"
        [[ -s "$file" ]] || rm -f "$file"
    fi
}

# One decision at a time: a second SUPER+R while a start is still writing the state is dropped, not a second
# recorder. The lock is released once the state file is written (start) or when this run ends.
exec 9>"$STATE_DIR/screen-record.lock"
flock -n 9 || exit 0

pid="$(running_pid)"
if [[ -z "$pid" && -e "$STATE_FILE" ]]; then # stale: the recorder was killed and nothing cleared the state
    rm -f "$STATE_FILE"
    tell_bar
fi
case "${1:-toggle}" in
    stop) [[ -n "$pid" ]] && kill -INT "$pid" ;;
    toggle) if [[ -n "$pid" ]]; then kill -INT "$pid"; else start; fi ;;
    *) echo "usage: screen-record.sh [toggle | stop]" >&2; exit 2 ;;
esac
exit 0
