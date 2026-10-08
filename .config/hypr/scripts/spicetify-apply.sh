#!/usr/bin/env bash
# matugen post_hook for Spotify colours (~/.config/matugen/config.toml, [templates.spicetify]); started in the
# background with `setsid -f`, so nobody sees its output.
# After a spicetify-cli upgrade `spicetify apply -n` only prints 'Please run "spicetify restore backup apply"', after
# a Spotify upgrade 'Please run "spicetify backup apply"', and exits 0 without applying: the colours silently stopped
# following the wallpaper (2026-10-06 → 2026-10-08, ticket 34). Run the suggested repair instead, and send a
# notification when Spotify still is not themed. A running Spotify keeps the old colours until it reloads, so send it
# Ctrl+Shift+R (its own reload shortcut) without focusing it (user's request 2026-10-08). Output of the last run: ~/.cache/spicetify-apply.log.
set -uo pipefail

LOG="${XDG_CACHE_HOME:-$HOME/.cache}/spicetify-apply.log"
mkdir -p "$(dirname "$LOG")"

# Quick wallpaper changes start several hooks; one spicetify at a time, each reads the newest color.ini.
exec 9> "${XDG_RUNTIME_DIR:-/tmp}/spicetify-apply.lock"
flock -w 120 9 || exit 1   # a hung spicetify must not queue every later hook forever

out="$(spicetify apply -n 2>&1)"; rc=$?
printf '%s\n' "\$ spicetify apply -n" "$out" > "$LOG"

repair=()
case "$out" in
    *"spicetify restore backup apply"*) repair=(restore backup apply -n) ;;
    *"spicetify backup apply"*) repair=(backup apply -n) ;;
esac
if (( ${#repair[@]} )); then
    out="$(spicetify "${repair[@]}" 2>&1)"; rc=$?
    printf '%s\n' "\$ spicetify ${repair[*]}" "$out" >> "$LOG"
fi

if (( rc != 0 )) || grep -qiE '(^|\s)error\s|spicetify (restore )?backup apply' <<< "$out"; then
    notify-send -a Spicetify "Spotify colours not applied" "See $LOG"
elif hyprctl -j clients | grep -q '"class": "Spotify"'; then
    hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "CTRL SHIFT", key = "R", window = "class:^(Spotify)$" })' >> "$LOG"
fi
