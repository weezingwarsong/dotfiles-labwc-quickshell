#!/bin/sh
action=$(notify-send -u critical -t 3000 -i system-reboot \
    "Reboot" "Click to cancel · Wait to proceed" \
    -A "default=Cancel" \
    --wait)

if [ "$action" != "default" ]; then
    systemctl reboot
fi
