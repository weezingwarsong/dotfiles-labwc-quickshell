#!/bin/sh
# Toggle the quickshell calendar panel via named FIFO
[ -p /tmp/qs-calendar-toggle ] && printf "toggle\n" > /tmp/qs-calendar-toggle
