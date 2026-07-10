#!/bin/bash
# yin-set: apply a wallpaper via the yin daemon.
# Starts yin if not running, waits for its socket, then hands the image off.

if [ -z "$1" ]; then
    echo "Usage: yin-set <image-or-video-path>" >&2
    exit 1
fi

# Start yin daemon if not running
if ! pgrep -x yin > /dev/null 2>&1; then
    yin &
    # Wait up to 5 s for yin's socket to appear
    i=0
    while [ ! -S /tmp/yin ] && [ "$i" -lt 10 ]; do
        sleep 0.5
        i=$((i + 1))
    done
fi

exec yinctl --img "$1"
