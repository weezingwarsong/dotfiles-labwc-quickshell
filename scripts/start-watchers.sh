#!/bin/sh
#
# start-watchers.sh
#
# Creates the IPC FIFO and starts qs-watcher as a self-restarting background
# daemon. Called from labwc/autostart before quickshell is launched.
#
# WHY FIFOs INSTEAD OF DIRECT PROCESS CHILDREN OF QUICKSHELL
# -----------------------------------------------------------
# The watcher connects to Wayland on startup. If it is spawned directly by
# quickshell there is a race: quickshell and the watcher both try to bind
# compositor protocols at the same time, right after labwc relogs. On relog
# labwc may not have finished advertising ext_workspace_manager_v1 and
# zwlr_foreign_toplevel_manager_v1 yet, so the watcher exits immediately with
# "not supported" and the window switcher and wallpaper-switching remain broken
# for the session.
#
# With the FIFO approach the watcher subshell starts here (before quickshell)
# but immediately blocks on the FIFO write-open — a FIFO open(O_WRONLY) blocks
# until a reader opens the other end. The daemon therefore stays suspended
# until quickshell has launched and opened its FIFO reader. By that point
# quickshell itself has already established a Wayland connection, which proves
# the compositor is fully up and all protocols are ready. The watcher then
# unblocks and connects without any race.
#
# RESTART LOOP
# ------------
# The daemon runs in a `while true; sleep 2` loop so that if the compositor
# disconnects (e.g. labwc --reconfigure) and the watcher exits, it restarts
# automatically after a 2-second back-off. quickshell mirrors this on its side
# with `while true; do cat /tmp/qs-watcher; done` so it handles the brief gap
# when the FIFO has no writer.

rm -f /tmp/qs-watcher
mkfifo /tmp/qs-watcher

(while true; do qs-watcher > /tmp/qs-watcher; sleep 2; done) &
