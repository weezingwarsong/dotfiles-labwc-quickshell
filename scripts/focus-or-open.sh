#!/bin/sh
# Usage: focus-or-open.sh <app_id> <launch_cmd> [args...]
# Focuses an open window by app_id; launches the command if none found.
APP_ID="$1"
shift
wlrctl toplevel focus "app_id:$APP_ID" 2>/dev/null || "$@" &
