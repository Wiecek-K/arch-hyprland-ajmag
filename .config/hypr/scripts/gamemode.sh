#!/usr/bin/env sh

# Check if animations are currently enabled (1 = enabled, 0 = disabled)
HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')

if [ "$HYPRGAMEMODE" = 1 ] ; then
    # IF NORMAL MODE -> ENABLE GAMEMODE (PERFORMANCE)
    # Disable animations, blur, shadows, rounding, and gaps
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
    
    # Send notification
    notify-send -u low -t 2000 "Gamemode" "Enabled (Max Performance)"
    exit
else
    # IF GAMEMODE ACTIVE -> RETURN TO NORMAL
    # Reloading config restores default values from hyprland.conf
    hyprctl reload
    
    # Send notification
    notify-send -u low -t 2000 "Gamemode" "Disabled (Visuals Restored)"
    exit 0
fi
