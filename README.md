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

## What's in the repo

```
dotfiles-labwc-quickshell/
├── quickshell/
│   ├── shell.qml                    # root — module switcher, workspace/recording state
│   ├── qmldir                       # required for local subfolder imports
│   ├── components/
│   │   ├── Time.qml                 # clock (HHmm) with slide-down calendar on hover
│   │   ├── Workspace.qml            # dual-square workspace indicator
│   │   ├── RecordingStatus.qml      # recording state indicator (RECORDING / RECORDING SAVED)
│   │   ├── WallpaperWindow.qml      # Background-layer wallpaper surface
│   │   └── qmldir
│   ├── scripts/
│   │   └── record-toggle.sh         # start/stop gpu-screen-recorder via PID file
│   └── wallpaper/                   # drop images here (sorted alphabetically → workspace 1, 2, …)
│
├── workspace-watcher/
│   └── main.c                       # C watcher using ext-workspace-v1 Wayland protocol
│
├── labwc/
│   ├── icons/                       # white SVG icons for the right-click menu
│   ├── autostart                    # starts quickshell, bluetooth, polkit agent
│   ├── environment                  # QT_QPA_PLATFORMTHEME, TERMINAL
│   ├── menu.xml                     # right-click root/client menu
│   └── rc.xml                       # keybinds and window rules
│
├── dependency                       # full package list with install commands
├── install.sh                       # symlinks configs, builds and installs workspace-watcher
└── .gitignore
```

---

## Features

**Single-slot bar** — one small centered widget at the top. Only one module is visible at a time; modules swap based on context.

**Time module** — shows the current time in `HHmm` format. Hovering slides down a calendar panel with the current month, today highlighted in Nord7.

**Workspace module** — two filled squares representing workspaces 1 (left) and 2 (right). Active workspace is Nord7, inactive is Nord3. Flashes in for 1 second on switch then returns to the time module. Workspace switching while recording is suppressed — recording takes priority.

**Recording module** — `Super+Shift+R` starts screen recording. The bar switches to "RECORDING" (Nord11 red). On stop, shows "RECORDING SAVED" (Nord14 green) for 1 second, then returns to time. Recordings saved to `~/Videos/`.

**Wallpaper** — images dropped into `quickshell/wallpaper/` are sorted alphabetically and assigned to workspaces in order (first → workspace 1, second → workspace 2, etc.). The wallpaper surface uses the `ext-workspace-v1` Wayland protocol layer and passes all pointer input through to the compositor.

**Native workspace detection** — a small C binary (`qs-workspace-watcher`) binds directly to labwc's `ext_workspace_manager_v1` Wayland protocol and emits the active workspace name on every state change. No polling, no file-based IPC.

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
| `Super + Tab` | Window switcher (native labwc) |
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
    labwc rofi \
    blueman \
    pipewire wireplumber pavucontrol-qt \
    gpu-screen-recorder qt6-multimedia grim slurp imv \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-utils \
    btop \
    gcc pkgconf wayland wayland-protocols \
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
- Symlink `labwc/` and `quickshell/` into `~/.config/`
- Compile `workspace-watcher/main.c` and install the binary to `~/.local/bin/qs-workspace-watcher`
- Install labwc menu icons to `~/.local/share/icons/hicolor/`

> Ensure `~/.local/bin` is in your `$PATH`.

### 3 — Wallpapers

Drop image files into `~/.config/quickshell/wallpaper/`. They are assigned to workspaces alphabetically — rename files to control the order (e.g. `1-mountains.jpg`, `2-forest.png`).

Supported formats: JPG, PNG, WebP, AVIF, SVG, GIF (animated), and video formats (WebM, MP4, etc.) via `qt6-multimedia`.

---

## Colour palette

All colours are strict [Nord](https://www.nordtheme.com/docs/colors-and-palettes).

| Group | Colours |
|---|---|
| Polar Night | `#2E3440` `#3B4252` `#434C5E` `#4C566A` |
| Snow Storm | `#D8DEE9` `#E5E9F0` `#ECEFF4` |
| Frost | `#8FBCBB` `#88C0D0` `#81A1C1` `#5E81AC` |
| Aurora | `#BF616A` `#D08770` `#EBCB8B` `#A3BE8C` `#B48EAD` |
