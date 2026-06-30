#!/bin/sh
#
# start-watchers.sh
#
# Cleans up any qs-watcher processes left over from a previous session.
# quickshell now spawns qs-watcher directly (no FIFO), so this script is a
# lightweight pre-flight: it guarantees the process slot is empty before the
# new quickshell instance starts and claims it.
#
# Called from labwc/autostart before quickshell is launched.

pkill -x qs-watcher 2>/dev/null || true
