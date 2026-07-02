#!/bin/sh
# Fires a desktop notification via mako/notify-send. Used by gcal_fetch.py
# so notification styling (app name, icon) lives in one place instead of
# being duplicated in the Python script.
#
# Usage: gcal-notify.sh <urgency: low|normal|critical> <summary> <body>

notify-send -a "Google Calendar Sync" -u "$1" "$2" "$3"
