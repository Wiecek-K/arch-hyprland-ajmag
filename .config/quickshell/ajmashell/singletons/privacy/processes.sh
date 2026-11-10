#!/usr/bin/env bash
# processes.sh — what the privacy list (bar/PrivacyPopup.qml) reads when it opens, to find the window or the tray
# icon of an app using a device (faza C ticket 05; parsed by privacy.mjs parseProcesses):
#   the process table (`ps -e -o pid=,ppid=`), to walk from a recording process up to its app's window;
#   "clients", then "client-id pid" per PipeWire client: a native client's stream (pw-record, OBS) carries no pid,
#     and Quickshell has no PipeWire clients; application.process.id first (pipewire-pulse's own pid is in
#     pipewire.sec.pid of every PulseAudio app);
#   "tray", then "pid bus-name object-path" per tray icon (StatusNotifierItem): an app closed to the tray (Discord)
#     has no window, its icon's Activate shows it.
# Tests: tools/test-privacy-processes.sh in the project. Own implementation.
set -u

ps -e -o pid=,ppid=

echo clients
pw-dump 2>/dev/null | jq -r '.[] | select(.type == "PipeWire:Interface:Client")
    | (.info.props["application.process.id"] // .info.props["pipewire.sec.pid"] // empty) as $pid
    | "\(.id) \($pid)"'

echo tray
items="$(busctl --user --json=short get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
    org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null | jq -r '.data[]' 2>/dev/null)"
while IFS= read -r item; do
    [[ -n "$item" ]] || continue
    name="${item%%/*}"
    path="/StatusNotifierItem" # an item registered by its bus name only
    [[ "$item" == */* ]] && path="/${item#*/}"
    pid="$(busctl --user --json=short call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
        GetConnectionUnixProcessID s "$name" 2>/dev/null | jq -r '.data[0]' 2>/dev/null)"
    [[ "$pid" =~ ^[0-9]+$ ]] && echo "$pid $name $path"
done <<< "$items"
