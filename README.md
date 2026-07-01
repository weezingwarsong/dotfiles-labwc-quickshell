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
│   │   ├── Time.qml                 # calendar panel, opens on TimePill hover
│   │   ├── WorkspacePill.qml        # bar content — dual-square workspace indicator (flashes on switch)
│   │   ├── MprisPill.qml            # bar content — MPRIS play/pause icon + track text
│   │   ├── Mpris.qml                # MPRIS player panel, opens on MprisPill hover
│   │   ├── RecordingPill.qml        # bar content — recording state (RECORDING / RECORDING SAVED)
│   │   ├── WindowPill.qml           # bar content — static "Window" label
│   │   ├── Window.qml               # window switcher panel — flat list, filter, keyboard nav
│   │   ├── WallpaperWindow.qml      # background-layer wallpaper surface
│   │   └── qmldir
│   └── wallpaper/                   # drop images here (sorted alphabetically → workspace 1, 2, …)
│
├── helper/watcher/
│   └── main.c                       # C binary (qs-watcher) — zwlr_foreign_toplevel_manager_v1 +
│                                    #   ext_workspace_manager_v1; emits JSON: {windows:[...], active_ws_name:"..."}
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

**Time module** — shows the current time in `HHmm` format. Hovering slides down a calendar panel with the current month, today highlighted in Nord7.

**Workspace module** — two filled squares representing workspaces 1 and 2. Active is Nord7, inactive is Nord3. Flashes for 1 second on switch then returns to the resting module.

**MPRIS module** — appears automatically when any audio player starts playing. Shows track title and artist. Hovering expands a player panel with album, playback controls, and a focus button that brings the player window to front. Dismisses 1 second after playback stops.

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
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji

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

- [ ] **Settings component** — a quickshell module (triggered by a keybind) for configuring user preferences at runtime without editing files. First candidate: the `focus-or-open.sh` app\_id mappings for `W-w` (browser) and `W-e` (file manager), so swapping browsers or file managers doesn't require touching rc.xml or the script. Settings would write to a small config file that the scripts and shell read.

- [ ] **Default apps** (under Settings) — replace hardcoded app references (e.g. `kitty` as terminal) with `xdg-open` and XDG MIME defaults so the system respects the user's preferred apps rather than baking names into scripts and keybinds.

- [ ] **Wallpaper management** — add a wallpaper panel/module to the settings component so wallpapers can be browsed and assigned to workspaces from the UI rather than by manually dropping files into the wallpaper folder with carefully sorted filenames. Also: the wallpaper module is currently broken and needs investigation.

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
