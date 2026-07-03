#!/bin/sh
# Toggle the quickshell MPRIS panel via named FIFO
[ -p /tmp/qs-mpris-toggle ] && printf "toggle\n" > /tmp/qs-mpris-toggle
