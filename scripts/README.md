# scripts

Helper scripts used by quickshell and labwc. Symlinked to `~/.config/scripts/` by `install.sh`.

| Script | Purpose | Referenced by |
|---|---|---|
| `record-toggle.sh` | Start/stop `gpu-screen-recorder` on monitor `DP-3`. Tracks PID in `/tmp/gsr-pid`. Saves recordings to `~/Videos/`. | `labwc/rc.xml` — `W-S-r` keybind · `quickshell/shell.qml` — `recordingCheck` Process reads `/tmp/gsr-pid` to detect state |
| `system-logout.sh` | Sends a cancellable `notify-send` confirmation, then runs `labwc --exit` if not cancelled. | `labwc/menu.xml` — Logout item |
| `system-reboot.sh` | Sends a cancellable `notify-send` confirmation, then runs `systemctl reboot` if not cancelled. | `labwc/menu.xml` — Reboot item |
| `system-shutdown.sh` | Sends a cancellable `notify-send` confirmation, then runs `systemctl poweroff` if not cancelled. | `labwc/menu.xml` — Shutdown item |
