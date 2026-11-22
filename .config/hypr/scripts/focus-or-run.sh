#!/usr/bin/env bash
# App shortcut that never does nothing (ticket c22, faza C): when the app already has a window, Ajmashell brings it
# to the focused workspace and focuses it (IPC `apps bring`, singletons/apps in the shell); otherwise the command
# runs as before (app not running, or only in the tray — a second start shows its window).
# Without Ajmashell (or an older one) the command runs as well.
# Usage: focus-or-run.sh <desktop id | --browser> <command...>
#   desktop id: the .desktop file name without ".desktop" (org.gnome.Nautilus)
#   --browser: the default web browser's entry (xdg-settings)
# Tests: ~/Projects/hyprland-lua-migration/tools/test-focus-or-run.sh
set -u

id="$1"
shift
[[ "$id" == --browser ]] && id="$(xdg-settings get default-web-browser 2>/dev/null)"
id="${id%.desktop}"

if [[ -n "$id" && "$(qs -c ajmashell ipc call apps bring "$id" 2>/dev/null)" == shown ]]; then
    exit 0
fi
exec "$@"
