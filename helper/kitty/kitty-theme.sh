#!/bin/sh
# Apply matugen-extracted colors to kitty.
# Usage: kitty-theme.sh <wallpaper-image-path>
#
# Reads ~/.config/matugen/config.toml (kitty template) and writes
# ~/.config/kitty/theme.conf, then signals kitty to reload.

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <wallpaper-image-path>" >&2
    exit 1
fi

IMAGE="$1"

if [ ! -f "$IMAGE" ]; then
    echo "Error: file not found: $IMAGE" >&2
    exit 1
fi

matugen image --config "$HOME/.config/matugen/config.toml" "$IMAGE"

pkill -SIGUSR1 kitty 2>/dev/null && echo "kitty reloaded" || echo "kitty not running (colors written, will apply on next launch)"
