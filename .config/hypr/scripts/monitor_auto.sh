#!/bin/bash

# Handle monitor disconnects to prevent black screen
# Requires: socat, jq

INTERNAL_MONITOR="eDP-1"

handle() {
  if [[ ${1:0:12} == "monitorremoved" ]]; then
    # Wait a split second for hyprland to update state
    sleep 0.5
    
    # Check how many monitors are connected
    MONITOR_COUNT=$(hyprctl monitors -j | jq 'length')
    
    # If no monitors are active (or only internal is physically present but disabled)
    # We force enable the internal monitor
    if [[ "$MONITOR_COUNT" == "0" ]]; then
        hyprctl keyword monitor "$INTERNAL_MONITOR, 1920x1080@60, 0x0, 1"
        notify-send "Monitor Disconnected" "Internal display re-enabled."
    else
        # Even if count is not 0, check if the remaining one is the internal one 
        # and if it was disabled (though usually count is 0 if disabled).
        # This is a failsafe re-enable.
        hyprctl keyword monitor "$INTERNAL_MONITOR, 1920x1080@60, 0x0, 1"
    fi
  fi
}

# Listen to Hyprland socket events
socat - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do handle "$line"; done
