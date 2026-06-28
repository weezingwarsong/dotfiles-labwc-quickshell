# dotfiles-labwc-quickshell

> CachyOS · labwc · quickshell · Nord

A Wayland desktop built on [labwc](https://github.com/labwc/labwc) with [quickshell](https://quickshell.outfoxxed.me/) replacing the traditional bar + notification daemon stack. Nord colour scheme throughout.

---

## Stack

| Layer | Tool |
|---|---|
| OS | CachyOS (Arch-based) |
| Compositor | labwc (wlroots, openbox-like) |
| Shell | quickshell (bar, notifications — QML-based) |
| Launcher | rofi |
| Notifications | quickshell (built-in) |
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
│   ├── shell.qml              # root — PanelWindow, module switcher, workspace watcher
│   └── modules/
│       ├── Time.qml           # clock (HHmm) with slide-down calendar on hover
│       └── Workspace.qml      # dual-square workspace indicator
│
├── labwc/
│   ├── icons/                 # white SVG icons for the right-click menu
│   ├── autostart              # starts quickshell, bluetooth, polkit agent
│   ├── environment            # QT_QPA_PLATFORMTHEME, TERMINAL
│   ├── menu.xml               # right-click root/client menu
│   └── rc.xml                 # keybinds and window rules
│
├── dependency                 # full package list
├── install.sh                 # symlinks configs into ~/.config
└── .gitignore
```

---

## Features

**Single-slot bar** — one small centered widget at the top of the screen. Only one module is visible at a time; modules swap in and out based on context.

**Time module** — shows the current time in `HHmm` format. Hovering slides down a calendar panel with the current month, today highlighted in Nord7.

**Workspace module** — two filled squares representing workspaces 1 (left) and 2 (right). The active workspace is highlighted in Nord7, the inactive one dimmed in Nord3. Flashes in for 1 second on workspace switch then returns to the time module.

**Event-driven workspace detection** — labwc keybinds write the active workspace number to `/tmp/qs-workspace`; quickshell watches with `tail -f` for near-instant response.

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
| `Super + F1 / F2` | Switch workspace |
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
    gpu-screen-recorder grim slurp imv \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-utils \
    btop \
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

### 2 — Symlink configs

```sh
git clone https://github.com/weezingwarsong/dotfiles-labwc-quickshell.git ~/Projects/github/dotfiles-labwc-quickshell
cd ~/Projects/github/dotfiles-labwc-quickshell
chmod +x install.sh
./install.sh
```

---

## Colour palette

All colours are strict [Nord](https://www.nordtheme.com/docs/colors-and-palettes).

| Group | Colours |
|---|---|
| Polar Night | `#2E3440` `#3B4252` `#434C5E` `#4C566A` |
| Snow Storm | `#D8DEE9` `#E5E9F0` `#ECEFF4` |
| Frost | `#8FBCBB` `#88C0D0` `#81A1C1` `#5E81AC` |
| Aurora | `#BF616A` `#D08770` `#EBCB8B` `#A3BE8C` `#B48EAD` |
