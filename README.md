# dotfiles-labwc-quickshell

> CachyOS · labwc · quickshell · Nord

A Wayland desktop built on [labwc](https://github.com/labwc/labwc) with [quickshell](https://quickshell.outfoxxed.me/) replacing the traditional bar + notification daemon stack. Nord colour scheme throughout.

---

## Stack

| Layer | Tool |
|---|---|
| OS | CachyOS (Arch-based) |
| Compositor | labwc (wlroots, openbox-like) |
| Shell | quickshell (bar, wallpaper, widgets — QML-based) |
| Launcher | rofi |
| Audio | PipeWire + WirePlumber |
| Theme | Nordic (GTK) + Nordic-bluish-solid (Kvantum) |
| Icons | Papirus-Dark + papirus-nord |
| Cursor | Nordzy-cursors-white |
| Font | JetBrainsMono Nerd Font |

---

## UI terminology

| Term | Definition |
|---|---|
| **Module** | A single view loaded into the main pill — e.g. *time*, *workspace indicator*, *MPRIS*, *window switcher*, *recording status*. Only one module is active at a time. |
| **Main pill** | The always-visible `Style.pillHeight` (24 px) bar element at the top-centre. Swaps its module based on context (recording > workspace flash > MPRIS > time) or on demand (window switcher via `Super+Tab`). |
| **Panel** | A container that spawns below the main pill on demand or on hover — e.g. the window list, the MPRIS player panel, the calendar. Panels are dismissed when the module changes or the user presses Escape. |

These names are also reflected in `Style.qml` token prefixes:
- `pill*` — background, border, height for the main pill
- `panel*` — background, border for spawned panels; `panelButton*` for interactive rows inside panels
- `textPill*` — text colours inside the main pill
- `textPanel*` — text colours inside spawned panels

---

## What's in the repo

```
dotfiles-labwc-quickshell/
├── quickshell/
│   ├── shell.qml                    # root — rigid bar + vertical roll transition, IPC readers, state
│   ├── components/
│   │   ├── Style.qml                # singleton — all colours, fonts, spacing tokens
│   │   ├── TimePill.qml             # bar content — clock (HHmm)
│   │   ├── Time.qml                 # calendar panel, opens on TimePill hover — agenda, navigable
│   │   │                            #   month grid + picker, weather box (temp/condition/hi-lo + icon), button rail
│   │   ├── WorkspacePill.qml        # bar content — dual-square workspace indicator (flashes on switch)
│   │   ├── MprisPill.qml            # bar content — MPRIS play/pause icon + marquee-scrolling track text
│   │   ├── Mpris.qml                # MPRIS player panel, opens on MprisPill hover — marquee title too
│   │   ├── RecordingPill.qml        # bar content — recording state (RECORDING / RECORDING SAVED)
│   │   ├── WindowPill.qml           # bar content — static "Window" label
│   │   ├── Window.qml               # window switcher panel — flat list, filter, keyboard nav
│   │   ├── WallpaperWindow.qml      # background-layer wallpaper surface
│   │   ├── PinButton.qml            # shared — thumbtack button that docks to a panel's top-right corner
│   │   ├── PanelIconButton.qml      # shared — square hover-grow icon button, Layout-safe (fixed footprint)
│   │   ├── PanelToolTip.qml         # shared — Nord-styled tooltip; instantiate directly, drive visible/text
│   │   └── qmldir
│   └── wallpaper/                   # drop images here (sorted alphabetically → workspace 1, 2, …)
│
├── helper/
│   ├── watcher/
│   │   └── main.c                   # C binary (qs-watcher) — zwlr_foreign_toplevel_manager_v1 +
│   │                                #   ext_workspace_manager_v1; emits JSON: {windows:[...], active_ws_name:"..."}
│   ├── calendar/
│   │   └── gcal_fetch.py            # Google Calendar sync — prints {"events":[...]} JSON. Fetch mode (default,
│   │                                #   for quickshell) never opens a browser; `--auth` does the OAuth consent
│   │                                #   flow by hand. Credentials live outside the repo, see below.
│   └── weather/
│       └── weather_fetch.py         # Open-Meteo sync — prints {temp, high, low, condition, icon} JSON. `icon` is
│                                    #   a Nerd Font nf-weather codepoint, chosen from the WMO code + day/night.
│                                    #   Location via IP geolocation (ipapi.co), cached 24h at ~/.config/weather-quickshell/.
│                                    #   Keyless — no credentials setup needed.
│
├── design/
│   └── sketches/                    # hand-drawn UI mockups referenced during implementation
│
├── mako/
│   └── config                       # mako notification daemon config (Nord, 90% opacity)
│
├── rofi/
│   └── config.rasi                  # rofi config
├── rofi-themes/
│   └── nord-custom.rasi             # Nord theme matching the quickshell pill aesthetic
│
├── scripts/                         # helper scripts (symlinked to ~/.config/scripts/)
│   ├── record-toggle.sh             # start/stop gpu-screen-recorder via PID file
│   ├── window-switch-toggle.sh      # writes "toggle" to /tmp/qs-window-toggle FIFO
│   └── README.md                    # script inventory
│
├── labwc/
│   ├── icons/                       # white SVG icons for the right-click menu
│   ├── autostart                    # starts quickshell, mako, bluetooth, polkit agent
│   ├── environment                  # PATH (includes ~/.local/bin), QT_QPA_PLATFORMTHEME, TERMINAL
│   ├── menu.xml                     # right-click root/client menu
│   └── rc.xml                       # keybinds and window rules
│
├── DESIGN.md                        # style system — colour tokens, rectangle/text semantics
├── dependency                       # full package list with install commands
├── install.sh                       # symlinks configs, builds and installs qs-watcher
└── .gitignore
```

---

## Features

**Single-slot bar** — one rigid rectangular bar at the top-center. The bar itself never moves or resizes; only one module's content is shown at a time, and switching between them rolls the outgoing text/icon out one edge while the incoming one rolls in from the other — like text printed on a cylinder rotating behind the bar. Priority order: recording > workspace flash > MPRIS > time.

**Time module** — shows the current time in `HHmm` format. Hovering slides down a wide calendar panel (independent panel width — see `_panelWidthFrac` in `shell.qml`; the pill itself never resizes); the panel stays open as long as the mouse is anywhere over the pill+panel region, not just the pill itself. Hovering continuously for 30s pins it open permanently (a thumbtack button appears to unpin). `Super+1` toggles it open/closed directly, independent of hover.
- **Agenda** (left) — today's events pulled from `gcal-fetch`, split into all-day and timed, with tooltips on truncated titles.
- **Month view** (middle) — navigable via prev/next triangle buttons or a month/year picker (click the month/year label; it inline-swaps to a year+month grid rather than a floating popup, since a fixed-size Wayland layer-shell surface has no "outside the window" for an overlay to render into). Days with events are highlighted with a tooltip listing them; today gets a hover-grow button treatment and, when the picker is open, the label becomes a "Today" shortcut back to the current month.
- **Weather** (below month view) — current temperature, condition, today's high/low, and a day/night Nerd Font weather glyph (nf-weather), pulled from `weather-fetch`. Location is auto-detected via IP geolocation (cached 24h) and weather data comes from [Open-Meteo](https://open-meteo.com/) — both keyless, no account/credentials setup needed.
- **Button rail** (right) — settings (inert, pending the Settings roadmap item), open-in-browser (`xdg-open` to Google Calendar), and a reserved placeholder.

**Workspace module** — two filled squares representing workspaces 1 and 2. Active is Nord7, inactive is Nord3. Flashes for 1 second on switch then returns to the resting module.

**MPRIS module** — appears automatically when any audio player starts playing. Shows track title and artist, both marquee-scrolling when too long to fit (pill: continuous one-way scroll-and-snap; panel: pause/scroll/pause/reverse). Hovering expands a player panel with album, playback controls, and a focus button that brings the player window to front; the panel stays open across the whole pill+panel region, not just the pill. Dismisses 1 second after playback stops, unless hovering continuously for 30s has pinned it open permanently (thumbtack button to unpin), which overrides the auto-dismiss.

**Calendar sync** — `helper/calendar/gcal_fetch.py` (installed as `gcal-fetch` on `PATH`) pulls Google Calendar events via OAuth and prints JSON; quickshell polls it every 5 minutes and caches the result client-side (window: -3 months to +24 months), so month navigation in the Time module never triggers a network call. Fetch mode never opens a browser — on auth failure it notifies (currently via `scripts/gcal-notify.sh`, a `notify-send` wrapper) and exits; re-auth is `gcal-fetch --auth`, run by hand. Credentials (`~/.config/gcal-quickshell/credentials.json` + cached `token.json`) live outside the repo, since it's public on GitHub.

**Window switcher** — `Super+Tab` opens a panel with all open windows in a flat list, a live filter input, and full keyboard navigation (Up/Down to move, Enter to focus, Escape or Super+Tab to dismiss). The currently focused window is shown muted. Powered by `qs-watcher`, a native C binary that listens to `zwlr_foreign_toplevel_manager_v1` — window list and active-window state update in real time with no polling.

**Recording module** — `Super+Shift+R` starts screen recording. The bar switches to "RECORDING" (Nord11 red). On stop, shows "RECORDING SAVED" (Nord14 green) for 1 second, then returns to the resting module. Recordings saved to `~/Videos/`.

**Wallpaper** — images dropped into `quickshell/wallpaper/` are sorted alphabetically and assigned to workspaces in order. Passes all pointer input through to the compositor.

**Notifications** — mako handles desktop notifications with the Nord palette at 90% opacity, matching the quickshell aesthetic.

**Native Wayland IPC** — no polling anywhere. A single C binary (`qs-watcher`) binds directly to compositor protocols:
- `zwlr_foreign_toplevel_manager_v1` — tracks all open windows and their state
- `ext_workspace_manager_v1` — tracks the active workspace name

Emits one compact JSON line per state change to stdout. quickshell spawns `qs-watcher` directly as a child process so its output flows straight into the parser with no FIFO in the middle. `start-watchers.sh` (called from autostart before quickshell) evicts any leftover watcher from a previous session. If the compositor disconnects (e.g. `labwc --reconfigure`), the watcher exits and quickshell respawns it after 2 s.

---

## Keybinds

### General
| Key | Action |
|---|---|
| `Super + Space` | Root menu |
| `Super + Escape` | Client menu |

### Workspaces
| Key | Action |
|---|---|
| `Super + F1 / F2` | Switch to workspace 1 / 2 |
| `Super + Scroll up/down` | Switch workspace (previous / next) |
| `Super + Shift + Scroll up/down` | Send window to workspace and follow |
| `Super + D` | Show desktop |

### Windows
| Key | Action |
|---|---|
| `Super + Tab` | Window switcher (quickshell) |
| `Super + 1` | Toggle calendar panel (quickshell) |
| `Alt + Tab / Alt + Shift + Tab` | Cycle windows forward / backward |
| `Super + Alt + X` / `Alt + F4` | Close window |
| `Super + Alt + F` | Maximize |
| `Super + Alt + D` | Minimize |
| `Super + Alt + Escape` | Toggle decorations |
| `Super + →/←/↑/↓` | Snap to edge |
| `Super + Alt + →/←/↑/↓` | Snap to corner |

### Apps
| Key | Action |
|---|---|
| `Super + T` | Terminal ($TERMINAL) |
| `Super + W` | Focus browser or open default browser |
| `Super + E` | Focus file manager or open pcmanfm-qt |
| `Super + H` | btop |
| `Super + V` | Volume control (pavucontrol-qt) |
| `Super + R` / `Alt + F2` | Rofi launcher |

### Capture
| Key | Action |
|---|---|
| `Super + Shift + S` | Area screenshot |
| `Super + Shift + D` | Full screenshot (1 s delay) |
| `Super + Shift + R` | Toggle screen recording |

### Media keys
| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume +5% |
| `XF86AudioLowerVolume` | Volume -5% |
| `XF86AudioMute` | Toggle mute |

---

## Install

### 1 — Dependencies

```sh
# pacman
sudo pacman -S \
    labwc rofi mako wlrctl \
    blueman \
    pipewire wireplumber pavucontrol-qt \
    gpu-screen-recorder qt6-multimedia grim slurp imv \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-utils \
    btop \
    gcc pkgconf wayland wayland-protocols wlr-protocols \
    kvantum qt5ct qt6ct \
    nordic-theme-git kvantum-theme-nordic-git \
    papirus-icon-theme \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
    python-google-api-python-client python-google-auth-oauthlib \
    python-google-auth-httplib2 python-cryptography

# AUR
yay -S \
    quickshell \
    nordzy-cursors \
    papirus-nord \
    rofi-polkit-agent
```

### 2 — Clone and install

```sh
git clone https://github.com/weezingwarsong/dotfiles-labwc-quickshell.git ~/Projects/github/dotfiles-labwc-quickshell
cd ~/Projects/github/dotfiles-labwc-quickshell
chmod +x install.sh
./install.sh
```

`install.sh` will:
- Symlink `labwc/`, `quickshell/`, `mako/`, `rofi/` and `scripts/` into `~/.config/`
- Compile `helper/watcher/main.c` → `~/.local/bin/qs-watcher`
- Install labwc menu icons to `~/.local/share/icons/hicolor/`

> `~/.local/bin` is added to `PATH` via `labwc/environment` so `qs-watcher` is found by quickshell. No manual PATH setup required.

### 3 — Wallpapers

Drop image files into `~/.config/quickshell/wallpaper/`. They are assigned to workspaces alphabetically — rename files to control the order (e.g. `1-mountains.jpg`, `2-forest.png`).

Supported formats: JPG, PNG, WebP, AVIF, SVG, GIF (animated), and video formats (WebM, MP4, etc.) via `qt6-multimedia`.

---

## Roadmap / To-do

- [x] **Calendar panel** — see the "Time module" and "Calendar sync" entries under Features above for the full shape of what's built: agenda, navigable month view + inline picker, event highlighting/tooltips, button rail, and the `gcal-fetch` backend wired into `shell.qml` as a periodic `Process`.
  > OAuth credentials (`~/.config/gcal-quickshell/credentials.json`, from Google Cloud Console) and the cached `token.json` live outside the repo — it's public on GitHub — so they're never committed and aren't part of `install.sh`; set up by hand per-machine with `gcal-fetch --auth`.
  - [x] Weather box — wired to `weather-fetch` (Open-Meteo + IP geolocation, both keyless), including a day/night Nerd Font condition icon mapped from the WMO weather code. See the "Weather" entry under Features above and `helper/weather/weather_fetch.py`.

- [ ] **Settings component** — a quickshell module (triggered by a keybind, and by the currently-inert settings button in the calendar panel's button rail) for configuring user preferences at runtime without editing files. Candidates:
  - [ ] **Default apps** — replace hardcoded app references (e.g. `kitty` as terminal, the `focus-or-open.sh` app\_id mappings for `W-w`/browser and `W-e`/file manager) with `xdg-open` and XDG MIME defaults, so swapping preferred apps doesn't require touching `rc.xml` or scripts by hand.
  - [ ] **Wallpaper management** — browse and assign wallpapers to workspaces from the UI rather than by manually dropping files into the wallpaper folder with carefully sorted filenames.
  - [ ] **Theme editor** — runtime overrides for the per-element color, opacity, and corner-radius tokens in `Style.qml` (pill, panel, panel-button, tooltip). `Style.qml` stays the shipped "default/reset" baseline — user overrides get written to a separate document (not this file) that the panel can save/load, rather than mutating `Style.qml` directly.

  Settings would write to a small config document that the scripts and shell read.

- [ ] **Panel open/close animation** — animate the expanded panels (MPRIS player, window switcher, calendar) to grow/shrink in height when they open/close, mirroring the bar's vertical roll transition instead of popping open instantly.

---

## Colour palette

All colours are strict [Nord](https://www.nordtheme.com/docs/colors-and-palettes).

| Group | Colours |
|---|---|
| Polar Night | `#2E3440` `#3B4252` `#434C5E` `#4C566A` |
| Snow Storm | `#D8DEE9` `#E5E9F0` `#ECEFF4` |
| Frost | `#8FBCBB` `#88C0D0` `#81A1C1` `#5E81AC` |
| Aurora | `#BF616A` `#D08770` `#EBCB8B` `#A3BE8C` `#B48EAD` |
