#!/bin/bash
PID_FILE="/tmp/gsr-pid"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill -INT "$(cat "$PID_FILE")"
    rm -f "$PID_FILE"
else
    mkdir -p "$HOME/Videos"
    OUTPUT="$HOME/Videos/$(date +%Y-%m-%d-%H%M%S)-recording.mp4"
    gpu-screen-recorder -w DP-3 -f 60 -o "$OUTPUT" &
    echo $! > "$PID_FILE"
fi
