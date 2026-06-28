#!/bin/sh
# Toggle the quickshell window-switch module via named FIFO
[ -p /tmp/qs-window-toggle ] && printf "toggle\n" > /tmp/qs-window-toggle
