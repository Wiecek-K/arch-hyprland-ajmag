#!/usr/bin/env bash
# XF86Audio keys on the player shown on the Bar (ticket c31, faza C): Ajmashell controls the player its media island
# and popup show (IPC `media key`, singletons/media in the shell: the one picked in the popup, else the playing one).
# Plain `playerctl` would take the first player on D-Bus, e.g. a paused Zen while Spotify plays.
# Without Ajmashell (restart, crash, an older shell) or with no player shown, playerctl runs as before.
# Usage: media-key.sh <play-pause | next | previous>
# Tests: ~/Projects/hyprland-lua-migration/tools/test-media-key.sh
set -u

if (($# != 1)); then
    echo "usage: media-key.sh <play-pause | next | previous>" >&2
    exit 2
fi

if [[ "$(qs -c ajmashell ipc call media key "$1" 2>/dev/null)" == "done" ]]; then
    exit 0
fi
exec playerctl "$1"
