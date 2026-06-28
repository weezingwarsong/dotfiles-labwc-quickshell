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
