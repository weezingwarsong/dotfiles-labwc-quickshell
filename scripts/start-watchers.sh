#!/bin/sh
#
# start-watchers.sh
#
# Creates the IPC FIFOs and starts qs-workspace-watcher and qs-toplevel-watcher
# as self-restarting background daemons. Called from labwc/autostart before
# quickshell is launched.
#
# WHY FIFOs INSTEAD OF DIRECT PROCESS CHILDREN OF QUICKSHELL
# -----------------------------------------------------------
# Both watchers connect to Wayland on startup. If they are spawned directly
# by quickshell (as quickshell child processes) there is a race: quickshell
# and the watchers all try to bind compositor protocols at the same time,
# right after labwc relogs. On relog labwc may not have finished advertising
# ext_workspace_manager_v1 and zwlr_foreign_toplevel_manager_v1 yet, so the
# watchers exit immediately with "not supported" and the window switcher and
# wallpaper-switching remain broken for the session.
#
# With the FIFO approach the watcher subshells start here (before quickshell)
# but immediately block on the FIFO write-open — a FIFO open(O_WRONLY) blocks
# until a reader opens the other end. The daemons therefore stay suspended
# until quickshell has launched and opened its FIFO readers. By that point
# quickshell itself has already established a Wayland connection, which proves
# the compositor is fully up and all protocols are ready. The watchers then
# unblock and connect without any race.
#
# RESTART LOOP
# ------------
# Each daemon runs in a `while true; sleep 2` loop so that if the compositor
# disconnects (e.g. labwc --reconfigure) and the watcher exits, it restarts
# automatically after a 2-second back-off. quickshell mirrors this on its side
# with `while true; do cat /tmp/qs-{workspace,toplevels}; done` so it handles
# the brief gap when the FIFO has no writer.

rm -f /tmp/qs-workspace /tmp/qs-toplevels
mkfifo /tmp/qs-workspace /tmp/qs-toplevels

(while true; do qs-workspace-watcher > /tmp/qs-workspace; sleep 2; done) &
(while true; do qs-toplevel-watcher  > /tmp/qs-toplevels; sleep 2; done) &
