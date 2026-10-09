#!/bin/bash
# SUPER+L. With the Ajmashell set active the shell's Panel zasilania opens instead of wlogout (ticket 18);
# wlogout stays on SUPER+SHIFT+L as the fallback.
if [[ "$("$HOME/.config/hypr/scripts/shellset.sh" active)" == ajmashell ]]; then
    exec qs -c ajmashell ipc call power toggle
fi
exec "$HOME/.config/hypr/scripts/Wlogout.sh"
