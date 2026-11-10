#!/usr/bin/env bash
# camera-users.sh — the processes holding a camera (/dev/video*) open, for the Bar's privacy dot (faza C ticket 05).
# PipeWire sees only apps that open the camera through it; Chrome and many others open /dev/video* directly
# (user, 2026-11-10: check that too). Prints "users<TAB>name<TAB>…" (process names, one per app, sorted; just
# "users" = none) at start and after each change only. Waits for an open / close of a camera with inotifywait and
# scans again; a scan every 5 s at most anyway, for a camera plugged in later and an event missed between two waits.
# PipeWire and WirePlumber are left out: an app using the camera through them is found by its PipeWire stream.
# Only the user's own processes can be read (/proc/PID/fd), which is enough for apps on the desktop.
# $CAMERA_PROC, $CAMERA_DEV: other /proc and /dev for the tests (tools/test-camera-users.sh in the project).
# Own implementation.
set -u

proc="${CAMERA_PROC:-/proc}"
dev="${CAMERA_DEV:-/dev}"
shopt -s nullglob

scan() {
    local -A seen=()
    local fd comm
    while IFS= read -r fd; do
        IFS= read -r comm < "${fd%/fd}/comm" 2>/dev/null || continue
        case "$comm" in pipewire | wireplumber) continue ;; esac
        seen["$comm"]=1
    done < <(find "$proc"/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' -printf '%h\n' 2>/dev/null | sort -u)
    printf 'users'
    if ((${#seen[@]})); then
        local names
        mapfile -t names < <(printf '%s\n' "${!seen[@]}" | sort) # process names may hold spaces
        printf '\t%s' "${names[@]}"
    fi
    printf '\n'
}

last=""
while :; do
    line="$(scan)"
    if [[ "$line" != "$last" ]]; then
        printf '%s\n' "$line" || exit 0 # the shell went away
        last="$line"
    fi
    devices=("$dev"/video*)
    if ((${#devices[@]})) && command -v inotifywait > /dev/null; then
        inotifywait -qq -t 5 -e open -e close "${devices[@]}"
        (($? == 1)) && sleep 5 # a device vanished between the glob and the watch
    else
        sleep 5
    fi
done
