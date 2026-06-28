#!/bin/sh
action=$(notify-send -u critical -t 3000 -i system-log-out \
    "Logout" "Click to cancel · Wait to proceed" \
    -A "default=Cancel" \
    --wait)

if [ "$action" != "default" ]; then
    labwc --exit
fi
