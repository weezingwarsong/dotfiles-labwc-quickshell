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

echo "Installing labwc-quickshell..."

link_dir labwc       labwc
link_dir quickshell  quickshell
link_dir scripts     scripts

# Build and install workspace watcher (requires gcc, pkg-config, wayland-scanner, wayland-protocols)
for cmd in gcc pkg-config wayland-scanner; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "  error: '$cmd' not found — install build dependencies (see dependency file)"; exit 1; }
done
echo "  building qs-workspace-watcher..."
BUILD_DIR="$DOTFILES/workspace-watcher"
PROTO_XML="/usr/share/wayland-protocols/staging/ext-workspace/ext-workspace-v1.xml"
wayland-scanner client-header "$PROTO_XML" "$BUILD_DIR/ext-workspace-v1-client-protocol.h"
wayland-scanner private-code   "$PROTO_XML" "$BUILD_DIR/ext-workspace-v1-client-protocol.c"
gcc -O2 -o "$BUILD_DIR/qs-workspace-watcher" \
    "$BUILD_DIR/main.c" \
    "$BUILD_DIR/ext-workspace-v1-client-protocol.c" \
    $(pkg-config --cflags --libs wayland-client)
mkdir -p "$HOME/.local/bin"
cp "$BUILD_DIR/qs-workspace-watcher" "$HOME/.local/bin/qs-workspace-watcher"
echo "  installed qs-workspace-watcher → ~/.local/bin"

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
echo "  Note: ensure ~/.local/bin is in your PATH for qs-workspace-watcher."
