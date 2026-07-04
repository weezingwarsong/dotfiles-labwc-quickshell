#!/bin/sh
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$HOME/.config"

link_dir() {
    src="$DOTFILES/$1"
    dst="$CONFIG/$2"
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    ln -s "$src" "$dst"
    echo "  linked $dst"
}

echo "Installing labwc-quickshell (Pillbox)..."

link_dir labwc       labwc
# Pillbox rewrite — the active quickshell config.
# The old implementation is preserved in quickshellold/ for reference.
link_dir quickshell  quickshell
link_dir scripts     scripts
link_dir mako        mako
link_dir rofi        rofi

# rofi theme lives outside ~/.config
mkdir -p "$HOME/.local/share/rofi/themes"
ln -snf "$DOTFILES/rofi-themes/nord-custom.rasi" "$HOME/.local/share/rofi/themes/nord-custom.rasi"
echo "  linked ~/.local/share/rofi/themes/nord-custom.rasi"

# DISABLED (Pillbox rewrite): qs-watcher was the old implementation's external
# binary for workspace and window tracking. Pillbox uses Quickshell's built-in
# ToplevelManager (wlr-foreign-toplevel-management) and ExtWorkspaceManager
# (ext-workspace-v1) instead — no compiled helper needed.
#
# for cmd in gcc pkg-config wayland-scanner; do
#     command -v "$cmd" >/dev/null 2>&1 || { echo "  error: '$cmd' not found — install build dependencies (see dependency file)"; exit 1; }
# done
# echo "  building qs-watcher..."
# BUILD_DIR="$DOTFILES/helper/watcher"
# WS_PROTO_XML="/usr/share/wayland-protocols/staging/ext-workspace/ext-workspace-v1.xml"
# WLR_PROTO_XML="/usr/share/wlr-protocols/unstable/wlr-foreign-toplevel-management-unstable-v1.xml"
# wayland-scanner client-header "$WS_PROTO_XML"  "$BUILD_DIR/ext-workspace-v1-client-protocol.h"
# wayland-scanner private-code   "$WS_PROTO_XML"  "$BUILD_DIR/ext-workspace-v1-client-protocol.c"
# wayland-scanner client-header "$WLR_PROTO_XML" "$BUILD_DIR/wlr-foreign-toplevel-management-unstable-v1-client-protocol.h"
# wayland-scanner private-code   "$WLR_PROTO_XML" "$BUILD_DIR/wlr-foreign-toplevel-management-unstable-v1-client-protocol.c"
# gcc -O2 -o "$BUILD_DIR/qs-watcher" \
#     "$BUILD_DIR/main.c" \
#     "$BUILD_DIR/ext-workspace-v1-client-protocol.c" \
#     "$BUILD_DIR/wlr-foreign-toplevel-management-unstable-v1-client-protocol.c" \
#     $(pkg-config --cflags --libs wayland-client)
# mkdir -p "$HOME/.local/bin"
# mv "$BUILD_DIR/qs-watcher" "$HOME/.local/bin/qs-watcher"
# echo "  installed qs-watcher → ~/.local/bin"

# Google integration scripts — symlinked so repo edits take effect immediately.
# All three share the same OAuth token at ~/.config/gcal-quickshell/token.json.
# Run `gcal-fetch --auth` once after install to complete the consent flow.
ln -snf "$DOTFILES/helper/calendar/gcal_fetch.py"    "$HOME/.local/bin/gcal-fetch"
echo "  linked gcal-fetch → ~/.local/bin"
ln -snf "$DOTFILES/helper/tasks/gtask_fetch.py"      "$HOME/.local/bin/gtask-fetch"
echo "  linked gtask-fetch → ~/.local/bin"
ln -snf "$DOTFILES/helper/google_auth_notify.sh"     "$HOME/.local/bin/google-auth-notify"
chmod +x "$DOTFILES/helper/google_auth_notify.sh"
echo "  linked google-auth-notify → ~/.local/bin"

# DISABLED (Pillbox rewrite): weather widget is not part of Pillbox.
# Kept here for reference in case it is reintroduced.
# ln -snf "$DOTFILES/helper/weather/weather_fetch.py" "$HOME/.local/bin/weather-fetch"
# echo "  linked weather-fetch → ~/.local/bin"

# Ensure ~/.local/bin is in labwc/environment PATH so quickshell can find gcal-fetch.
# labwc reads this file before launching child processes; the user's shell PATH is not inherited.
LOCAL_BIN="$HOME/.local/bin"
ENV_FILE="$DOTFILES/labwc/environment"
if ! grep -q "^PATH=.*$LOCAL_BIN" "$ENV_FILE" 2>/dev/null; then
    printf "\n  ~/.local/bin is not in labwc/environment PATH.\n"
    printf "  quickshell needs this to find qs-watcher/gcal-fetch/weather-fetch at runtime.\n"
    printf "  Add it automatically? [Y/n] "
    read -r _answer
    if [ "${_answer:-y}" != "n" ] && [ "${_answer:-y}" != "N" ]; then
        if grep -q "^PATH=" "$ENV_FILE" 2>/dev/null; then
            sed -i "s|^PATH=|PATH=$LOCAL_BIN:|" "$ENV_FILE"
        else
            printf "PATH=%s:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl\n" "$LOCAL_BIN" >> "$ENV_FILE"
        fi
        echo "  added ~/.local/bin to PATH in labwc/environment"
    else
        echo "  skipped — add PATH=~/.local/bin:\$PATH to labwc/environment manually or qs-watcher/gcal-fetch/weather-fetch won't be found"
    fi
fi

# labwc menu icons — white variants installed to hicolor so labwc finds them by name
HICOLOR="$HOME/.local/share/icons/hicolor"
mkdir -p "$HICOLOR/22x22/apps" "$HICOLOR/22x22/actions"
ln -snf "$DOTFILES/labwc/icons/menu-web-browser.svg" "$HICOLOR/22x22/apps/menu-web-browser.svg"
ln -snf "$DOTFILES/labwc/icons/menu-run.svg"         "$HICOLOR/22x22/actions/menu-run.svg"
ln -snf "$DOTFILES/labwc/icons/menu-terminal.svg"    "$HICOLOR/22x22/apps/menu-terminal.svg"
ln -snf "$DOTFILES/labwc/icons/menu-logout.svg"      "$HICOLOR/22x22/actions/menu-logout.svg"
ln -snf "$DOTFILES/labwc/icons/menu-steam.svg"       "$HICOLOR/22x22/apps/menu-steam.svg"
echo "  linked labwc menu icons → hicolor"

echo ""
echo "Done."
echo "  Note: ensure ~/.local/bin is in your PATH for gcal-fetch/gtask-fetch."
echo "  Note: gcal-fetch and gtask-fetch need ~/.config/gcal-quickshell/credentials.json (Google OAuth client, not in this repo)."
echo "        Run 'gcal-fetch --auth' once to complete the consent flow (covers both Calendar and Tasks)."
echo "  Note: Pillbox FIFO lives at ~/.local/share/pillbox/pillbox.fifo — created automatically on first run."
echo "        labwc keybinds should write commands to that path (e.g. echo 'showTime' > ~/.local/share/pillbox/pillbox.fifo)."
