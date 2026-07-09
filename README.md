# dotfiles-labwc-quickshell

> CachyOS · labwc · Pillbox · Nord

A Wayland desktop built on [labwc](https://github.com/labwc/labwc). The centrepiece is **Pillbox** — a custom QML shell written in Quickshell that replaces the traditional bar, launcher overlay, and eventually the notification daemon with two visual primitives: Pills and Panels.

---

## Stack

| Layer | Tool | Notes |
|---|---|---|
| OS | CachyOS (Arch-based) | |
| Compositor | labwc | wlroots, openbox-like keybinds |
| Shell | Quickshell / Pillbox | QML — see `quickshell/` |
| Launcher | rofi | drun mode |
| Notifications | mako | temporary — Pillbox will own this eventually |
| Wallpaper | yin | ffmpeg-backed Wayland daemon; Pillbox calls `yinctl` |
| Audio | PipeWire + WirePlumber | |
| GTK theme | Nordic | `nordic-theme-git` (GTK3 + GTK4) |
| Qt theme | Kvantum + Nordic | `kvantum-theme-nordic-git`; configured via qt5ct / qt6ct |
| Icons | Papirus-Dark + papirus-nord | Nord colour variant |
| Cursor | Nordzy-cursors-white | |
| Font | JetBrains Mono Nerd Font | all text + Nerd Font glyphs in Pillbox |
| CJK font | Sarasa Mono SC | fontconfig fallback for CJK track names, event titles |

---

## Pillbox

Pillbox replaces the bar stack with two visual primitives:

**Pill** — a 24px rounded rectangle anchored top-centre. Hidden by default. One active at a time. Reveals automatically when there is something worth showing (imminent calendar event, workspace switch, track change), or on demand via hover and the W-1 latch. Priority order: WindowPill (switcher open) → WorkspacePill (workspace flash) → TimePill urgent (event ≤ 10 min or timer active) → MprisPill (playing) → TimePill fallback (always).

**Panel** — a larger overlay below the Pill. Opens only on deliberate user action (keybind), closes on the same keybind, ESC, or click-outside. One panel at a time. Left/right arrow keys and floating ‹ › buttons navigate between panels in keybind order.

| Keybind | Panel |
|---|---|
| W-2 | Calendar (events, tasks, weather, timer) |
| W-3 | Media Player (MPRIS — album art, controls, volume) |
| W-4 | Settings (services + appearance) |
| W-5 | Wallpaper (colour swatches + image/video browser) |
| W-Tab | Window Switcher (live filter, keyboard nav) |

Full architecture and module specs: `quickshell/docs/`. Start with `quickshell/CLAUDE.md` for a quick orientation.

---

## Theming

Nord palette throughout. Pillbox owns its own colour tokens (`Style.qml`) and will eventually generate them from wallpaper extraction (pywal/matugen format). Everything outside Pillbox needs separate wiring:

### GTK apps
Nordic GTK theme handles GTK3 and GTK4. No per-app configuration required.

### Qt apps
Qt apps do not obey GTK theming. The current solution is:
- **Kvantum** — theming engine for Qt5 and Qt6. Set to `Nordic-Darker` in `kvantum-manager`.
- **qt5ct / qt6ct** — set `QT_STYLE_OVERRIDE=kvantum` via `labwc/environment`. Applies to all Qt apps launched by labwc.

This works but is manual. The longer-term goal — once Pillbox is feature-complete — is a unified system where the Nord palette is the single source of truth: Pillbox exports its active palette (whether Nord default or extracted from wallpaper) and Qt/GTK theming consumes it automatically. The mechanism is TBD; pywal-style config-file generation is the likely path.

### Icons and cursor
Papirus-Dark + papirus-nord for icons, Nordzy-cursors-white for cursor. Set via `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini`, and the Kvantum / qt6ct icon setting.

### Fonts
JetBrains Mono Nerd Font everywhere — terminal, editor, Pillbox text and glyphs. Set as the monospace font in qt5ct/qt6ct and GTK settings.

---

## Notifications

mako handles desktop notifications today (config in `mako/`, Nord palette, semi-transparent). Once Pillbox implements a notification layer (planned), mako will be removed. The intent is that Pillbox owns the full DE surface — bar, panels, wallpaper, notifications — so theming is one system rather than three.

---

## What's in the repo

```
dotfiles-labwc-quickshell/
├── quickshell/                   ← Pillbox shell (canonical source)
│   ├── CLAUDE.md                 ← session orientation; start here
│   ├── docs/                     ← architecture, modules, style, components, completed work
│   ├── module-panels/            ← CalendarPanel, SettingsPanel, WallpaperPanel, WindowSwitcherPanel
│   ├── module-pills/             ← TimePill, WorkspacePill, WindowPill, MprisPill, ScreenrecPill (stub)
│   ├── module-reusable-elements/ ← PillController, PanelSurface, PanelButton, TogglePair, etc.
│   ├── root-processes/           ← CalendarProcess, WeatherProcess, MprisProcess, WallpaperProcess, etc.
│   ├── Prefs.qml                 ← user preferences (font sizes, radius, borders, wallpaper state)
│   ├── Style.qml                 ← all visual tokens (Nord palette → semantic names)
│   └── shell.qml                 ← ShellRoot; instantiates everything
│
├── helper/
│   ├── calendar/gcal_fetch.py    ← Google Calendar sync (symlinked → ~/.local/bin/gcal-fetch)
│   ├── tasks/gtask_fetch.py      ← Google Tasks sync (symlinked → ~/.local/bin/gtask-fetch)
│   ├── weather/weather_fetch.py  ← Open-Meteo weather (symlinked → ~/.local/bin/weather-fetch)
│   ├── google_auth_notify.sh     ← re-auth desktop notification (symlinked → ~/.local/bin/google-auth-notify)
│   └── watcher/                  ← legacy C binary (superseded; kept for reference)
│
├── labwc/
│   ├── rc.xml                    ← keybinds and window rules
│   ├── autostart                 ← starts quickshell, mako, yin, bluetooth, polkit agent
│   ├── environment               ← PATH, QT_QPA_PLATFORMTHEME, TERMINAL
│   ├── menu.xml                  ← right-click root/client menu
│   └── icons/                    ← white SVG icons for labwc menu
│
├── mako/config                   ← notification daemon config (temporary)
├── rofi/config.rasi              ← rofi launcher config
├── rofi-themes/nord-custom.rasi  ← Nord rofi theme
├── scripts/                      ← helper scripts (symlinked → ~/.config/scripts/)
├── dependency                    ← full package list with install commands
└── install.sh                    ← symlinks configs, installs helper scripts
```

---

## Keybinds

### Pillbox
| Key | Action |
|---|---|
| `W-1` | Latch pill on/off (persistent toggle) |
| `W-2` | Toggle Calendar panel |
| `W-3` | Toggle Media Player panel |
| `W-4` | Toggle Settings panel |
| `W-5` | Toggle Wallpaper panel |
| `W-Tab` | Toggle Window Switcher |

### Workspaces
| Key | Action |
|---|---|
| `W-F1` / `W-F2` | Switch to workspace 1 / 2 |
| `W-d` | Show desktop |

### Windows
| Key | Action |
|---|---|
| `A-Tab` / `A-S-Tab` | Cycle windows forward / backward |
| `W-A-x` / `A-F4` | Close window |
| `W-A-f` | Maximize |
| `W-A-d` | Minimize |
| `W-A-Escape` | Toggle decorations |
| `W-←/→/↑/↓` | Snap to edge |
| `W-A-←/→/↑/↓` | Snap to corner |

### Apps
| Key | Action |
|---|---|
| `W-space` | Root menu |
| `W-Escape` | Client menu |
| `W-r` / `A-F2` | Rofi launcher |
| `W-t` | Terminal (`$TERMINAL`) |
| `W-w` | Focus browser or open default browser |
| `W-e` | Focus file manager or open pcmanfm-qt |
| `W-h` | btop |
| `W-v` | pavucontrol-qt |

### Capture
| Key | Action |
|---|---|
| `W-S-s` | Area screenshot |
| `W-S-d` | Full screenshot (1 s delay) |
| `W-S-r` | Toggle screen recording |

### Media keys
| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume +5% |
| `XF86AudioLowerVolume` | Volume -5% |
| `XF86AudioMute` | Toggle mute |

---

## Install

### 1 — Dependencies

See `dependency` for the full annotated list. Quick install:

```sh
# pacman
sudo pacman -S \
    labwc rofi mako wlrctl \
    blueman \
    pipewire wireplumber pavucontrol-qt \
    gpu-screen-recorder qt6-multimedia grim slurp imv \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-utils \
    btop \
    kvantum qt5ct qt6ct \
    nordic-theme-git kvantum-theme-nordic-git \
    papirus-icon-theme \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
    python-google-api-python-client python-google-auth-oauthlib \
    python-google-auth-httplib2 python-cryptography

# AUR
yay -S quickshell yin nordzy-cursors papirus-nord rofi-polkit-agent ttf-sarasa-gothic
```

### 2 — Clone and install

```sh
git clone https://github.com/weezingwarsong/dotfiles-labwc-quickshell.git ~/Projects/github/dotfiles-labwc-quickshell
cd ~/Projects/github/dotfiles-labwc-quickshell
chmod +x install.sh
./install.sh
```

`install.sh` symlinks `labwc/`, `quickshell/`, `mako/`, `rofi/`, and `scripts/` into `~/.config/`, installs helper scripts to `~/.local/bin/`, and links labwc menu icons.

### 3 — Google Calendar / Tasks

Credentials (`~/.config/gcal-quickshell/credentials.json`) are not in the repo. Obtain an OAuth client from Google Cloud Console, place it at that path, then run:

```sh
gcal-fetch --auth
```

This covers both Calendar and Tasks (shared token). After that, Pillbox polls automatically.

### 4 — Wallpaper daemon

yin must be running before Pillbox starts. Add it to `labwc/autostart`:

```sh
yin &
```

Pillbox's Wallpaper panel calls `yinctl` to set image/video wallpapers. Solid colour mode does not require yin.

---

## Roadmap

### Pillbox — in progress
- [x] Media Player panel (W-3) — MPRIS controls, album art, volume
- [ ] Notification layer — Pillbox takes over from mako; mako removed
- [ ] ScreenrecPill — recording indicator (stub registered, not yet implemented)
- [ ] Style system finalization — palette extraction (pywal/matugen), fix candidates resolved, v2 tokens
- [ ] Wallpaper panel — testing and touch-up; video thumbnails via ffmpeg

### Theming — after Pillbox is complete
- [ ] Unified palette export — Pillbox active palette (Nord default or wallpaper-extracted) written to a file that GTK and Qt theming can consume
- [ ] Qt theming automation — eliminate manual qt5ct/Kvantum setup; Qt apps inherit the active Nord palette automatically
