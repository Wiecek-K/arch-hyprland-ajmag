#!/bin/bash

MONITOR_NAME="HDMI-A-2"
PID_FILE="/tmp/gif_recorder.pid"
VIDEO_FILE="/tmp/temp_video.mp4"
OUTPUT_FILE="$HOME/Videos/recording_$(date +%s).gif"

if [ -f "$PID_FILE" ]; then
    kill -INT $(cat "$PID_FILE")
    rm "$PID_FILE"
    
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    
    notify-send "Processing" "Converting video to GIF..."
    ffmpeg -v warning -i "$VIDEO_FILE" -vf "fps=15,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "$OUTPUT_FILE" -y
    rm "$VIDEO_FILE"
    
    notify-send "Success" "GIF saved: $OUTPUT_FILE"
else
    wf-recorder -o "$MONITOR_NAME" -f "$VIDEO_FILE" &
    echo $! > "$PID_FILE"
    notify-send "Recording" "Capturing monitor: $MONITOR_NAME"
fi
