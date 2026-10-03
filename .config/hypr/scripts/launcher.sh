#!/bin/bash
# SUPER+D. With the Ajmashell set active the shell's launcher opens instead of rofi (ticket 11);
# rofi stays on SUPER+SHIFT+D as the fallback.
if [[ "$("$HOME/.config/hypr/scripts/shellset.sh" active)" == ajmashell ]]; then
    exec qs -c ajmashell ipc call launcher toggle
fi
exec rofi -show drun
