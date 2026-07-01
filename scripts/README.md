# scripts

Helper scripts used by quickshell and labwc. Symlinked to `~/.config/scripts/` by `install.sh`.

| Script | Purpose | Referenced by |
|---|---|---|
| `start-watchers.sh` | Creates `/tmp/qs-workspace` and `/tmp/qs-toplevels` FIFOs, then starts `qs-workspace-watcher` and `qs-toplevel-watcher` as self-restarting background daemons that write to those FIFOs. Must run **before** `quickshell` in the autostart — see the script header for the full explanation of why the FIFO approach is used. | `labwc/autostart` — called before `quickshell &` |
| `record-toggle.sh` | Start/stop `gpu-screen-recorder` on monitor `DP-3`. Tracks PID in `/tmp/gsr-pid`. Saves recordings to `~/Videos/`. | `labwc/rc.xml` — `W-S-r` keybind · `quickshell/shell.qml` — `recordingCheck` Process reads `/tmp/gsr-pid` to detect state |
| `window-switch-toggle.sh` | Writes `"toggle"` to the `/tmp/qs-window-toggle` FIFO (only if the FIFO exists) to open or close the quickshell window-switcher panel. | `labwc/rc.xml` — `W-Tab` keybind |
| `calendar-toggle.sh` | Writes `"toggle"` to the `/tmp/qs-calendar-toggle` FIFO (only if the FIFO exists) to force the bar to "time" and pin the calendar panel open, or unpin/close it. | `labwc/rc.xml` — `W-1` keybind |
| `focus-or-open.sh` | Focuses an existing window by `app_id` using `wlrctl`; if none is found, launches the given command instead. Usage: `focus-or-open.sh <app_id> <cmd> [args…]` | `labwc/rc.xml` — `W-w` (browser) and `W-e` (file manager) keybinds |
| `system-logout.sh` | Sends a cancellable `notify-send` confirmation, then runs `labwc --exit` if not cancelled. | `labwc/menu.xml` — Logout item |
| `system-reboot.sh` | Sends a cancellable `notify-send` confirmation, then runs `systemctl reboot` if not cancelled. | `labwc/menu.xml` — Reboot item |
| `system-shutdown.sh` | Sends a cancellable `notify-send` confirmation, then runs `systemctl poweroff` if not cancelled. | `labwc/menu.xml` — Shutdown item |
