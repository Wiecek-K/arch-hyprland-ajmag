#!/usr/bin/env bash
# matugen post_hook for Spotify colours (~/.config/matugen/config.toml, [templates.spicetify]); started in the
# background with `setsid -f`, so nobody sees its output.
# After a spicetify-cli upgrade `spicetify apply -n` only prints 'Please run "spicetify restore backup apply"', after
# a Spotify upgrade 'Please run "spicetify backup apply"', and exits 0 without applying: the colours silently stopped
# following the wallpaper (2026-10-06 → 2026-10-08, ticket 34). Run the suggested repair instead, and send a
# notification when Spotify still is not themed. A running Spotify keeps the old colours until it reloads, so send it
# Ctrl+Shift+R (its own reload shortcut) without focusing it (user's request 2026-10-08). Output of the last run: ~/.cache/spicetify-apply.log.
# When Spotify is upgraded while spiced up and the backup is older, both commands only print 're-install Spotify …'
# (2026-10-14, ticket 49): no repair possible here, so that text also counts as a failure and sends the notification.
# Faster path (ticket 49, 2026-10-15): the live-colors.js spicetify extension reloads only colors.css on Ctrl+Shift+F12,
# without the ~1 s blank page of Ctrl+Shift+R, and `spicetify refresh -s` writes colors.css in ~0.13 s instead of ~1 s
# for apply. Only when the extension is in Spotify's index.html (apply puts it there) and spicetify-cli is the version
# the backup was made with: refresh does not check that (apply does), so after a CLI upgrade it would skip the repair.
# Anything else, or a refresh that fails or prints a hint, takes the apply path below.
set -uo pipefail

LOG="${XDG_CACHE_HOME:-$HOME/.cache}/spicetify-apply.log"
mkdir -p "$(dirname "$LOG")"

# Quick wallpaper changes start several hooks; one spicetify at a time, each reads the newest color.ini.
exec 9> "${XDG_RUNTIME_DIR:-/tmp}/spicetify-apply.lock"
flock -w 120 9 || exit 1   # a hung spicetify must not queue every later hook forever

spotify_open() { hyprctl -j clients | grep -qE '"class": "[Ss]potify"'; }
send() { hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"CTRL SHIFT\", key = \"$1\", window = \"class:^([Ss]potify)\$\" })" >> "$LOG"; }
failed() { (( rc != 0 )) || grep -qiE '(^|\s)error\s|spicetify (restore )?backup apply|re-install Spotify' <<< "$out"; }

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/spicetify/config-xpui.ini"
ini() { sed -n "s/^$1 *= *//p" "$CONFIG" 2>/dev/null | head -n 1; }
xpui="$(ini spotify_path)Apps/xpui"
: > "$LOG"
if grep -q "extensions/live-colors.js" "$xpui/index.html" 2>/dev/null && [[ "$(spicetify -v 2>/dev/null)" == "$(ini with)" ]]; then
    out="$(spicetify refresh -s -n 2>&1)"; rc=$?
    printf '%s\n' "\$ spicetify refresh -s -n" "$out" >> "$LOG"
    if ! failed; then
        spotify_open && send F12
        exit 0
    fi
fi

out="$(spicetify apply -n 2>&1)"; rc=$?
printf '%s\n' "\$ spicetify apply -n" "$out" >> "$LOG"

repair=()
case "$out" in
    *"spicetify restore backup apply"*) repair=(restore backup apply -n) ;;
    *"spicetify backup apply"*) repair=(backup apply -n) ;;
esac
if (( ${#repair[@]} )); then
    out="$(spicetify "${repair[@]}" 2>&1)"; rc=$?
    printf '%s\n' "\$ spicetify ${repair[*]}" "$out" >> "$LOG"
fi

if failed; then
    notify-send -a Spicetify "Spotify colours not applied" "See $LOG"
elif spotify_open; then
    send R
fi
