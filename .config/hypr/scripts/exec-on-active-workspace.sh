#!/usr/bin/env bash

# Start a program on the workspace that is active now, not on the one focused when its window
# finally appears (slow Electron apps). Used by the .desktop overrides from my-patch-workspace-tracking.sh.
# A separate script, because a quoted `sh -c '...'` in Exec= is not valid Desktop Entry syntax
# (only double quotes are) — Quickshell's parser split it and the Ajmashell launcher started nothing (2026-10-06).

ws=$(hyprctl activeworkspace -j | jq -r .id)
cmd=$(printf '%q ' "$@")
hyprctl dispatch "hl.dsp.exec_cmd([[${cmd% }]], { workspace = \"$ws\" })"
