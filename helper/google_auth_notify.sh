#!/usr/bin/env bash
# Sends a re-authentication notification for Pillbox's Google integration.
# Called as a detached background subprocess by gcal-fetch/gtask-fetch — never blocks them.
# If the user clicks "Re-authenticate", opens $TERMINAL with gcal-fetch --auth,
# which refreshes the shared token (calendar.readonly + tasks.readonly) for both scripts.

action=$(notify-send \
    --app-name "Pillbox" \
    --urgency critical \
    --action "auth=Re-authenticate" \
    --wait \
    "Google re-authentication required" \
    "Calendar and Tasks data is paused. Click to re-authenticate, or run: gcal-fetch --auth")

if [ "$action" = "auth" ]; then
    ${TERMINAL:-foot} -e gcal-fetch --auth
fi
