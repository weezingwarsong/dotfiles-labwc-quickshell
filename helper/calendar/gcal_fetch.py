#!/usr/bin/env python3
# Fetches events from the user's primary Google Calendar and prints them as
# one JSON object to stdout: {"events": [...]}. Read-only (calendar.readonly
# scope) — the panel's "open in browser" button handles editing.
#
# Auth state lives outside the repo (it's public on GitHub) at
# ~/.config/gcal-quickshell/: credentials.json (OAuth client, from Google
# Cloud Console) and token.json (cached user token).
#
# Two modes:
#   gcal_fetch.py         fetch mode — used by quickshell on a timer. Never
#                          opens a browser; if re-auth is needed, notifies
#                          via notify-send and exits instead of fetching.
#   gcal_fetch.py --auth   interactive mode — run this by hand (initial setup,
#                          or after the refresh token expires) to do the OAuth
#                          consent flow, then confirms with a fetch.
#
# While the OAuth consent screen is in "Testing" publishing status, Google
# expires the refresh token after 7 days, so fetch mode will periodically
# need a manual `--auth` run. Publishing the app (Audience tab -> Publish
# App) removes that 7-day cap.

import datetime
import fcntl
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import httplib2
from google.auth.exceptions import RefreshError
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_httplib2 import AuthorizedHttp
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]
CONFIG_DIR = Path.home() / ".config" / "gcal-quickshell"
CREDENTIALS_FILE = CONFIG_DIR / "credentials.json"
TOKEN_FILE = CONFIG_DIR / "token.json"
LOCK_FILE = CONFIG_DIR / "gcal_fetch.lock"
HTTP_TIMEOUT_SECS = 15
NOTIFY_SCRIPT = Path.home() / ".config" / "scripts" / "gcal-notify.sh"


def notify(summary, body, urgency="normal"):
    try:
        subprocess.run([str(NOTIFY_SCRIPT), urgency, summary, body], check=False, timeout=5)
    except FileNotFoundError:
        print(f"[notify:{urgency}] {summary}: {body}", file=sys.stderr)


def acquire_lock():
    # Kept open (and referenced) for the life of the process — the lock
    # releases automatically on exit, including a crash, so there's no
    # stale-lock cleanup to worry about (unlike a PID file).
    lock_file = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        notify("Google Calendar sync", "Another instance is already running — skipping this fetch.")
        sys.exit(0)
    return lock_file


def _write_token(creds):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=CONFIG_DIR, prefix=".token.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(creds.to_json())
        os.chmod(tmp_path, 0o600)
        os.replace(tmp_path, TOKEN_FILE)
    except BaseException:
        os.unlink(tmp_path)
        raise


def _load_cached_credentials():
    if not TOKEN_FILE.exists():
        return None
    try:
        return Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
    except (ValueError, json.JSONDecodeError):
        return None  # corrupt token file — treat as absent


def get_credentials(interactive):
    creds = _load_cached_credentials()

    if creds and creds.valid:
        return creds

    if creds and creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())  # google-auth defaults this call's timeout to 120s
            _write_token(creds)
            return creds
        except RefreshError:
            creds = None  # refresh token itself is dead — needs full reauth

    if not interactive:
        notify(
            "Google Calendar sync",
            "Re-authorization required — run: gcal_fetch.py --auth",
            urgency="critical",
        )
        sys.exit(1)

    if not CREDENTIALS_FILE.exists():
        sys.exit(f"error: missing {CREDENTIALS_FILE} — download OAuth client credentials from Google Cloud Console")

    flow = InstalledAppFlow.from_client_secrets_file(str(CREDENTIALS_FILE), SCOPES)
    creds = flow.run_local_server(port=0)
    _write_token(creds)
    return creds


def fetch_events(creds, days_ahead=7, max_results=20):
    authed_http = AuthorizedHttp(creds, http=httplib2.Http(timeout=HTTP_TIMEOUT_SECS))
    service = build("calendar", "v3", http=authed_http, cache_discovery=False)

    now = datetime.datetime.now(datetime.timezone.utc)
    time_min = now.isoformat()
    time_max = (now + datetime.timedelta(days=days_ahead)).isoformat()

    result = service.events().list(
        calendarId="primary",
        timeMin=time_min,
        timeMax=time_max,
        maxResults=max_results,
        singleEvents=True,
        orderBy="startTime",
    ).execute(num_retries=2)

    events = []
    for item in result.get("items", []):
        start = item["start"].get("dateTime", item["start"].get("date"))
        end = item["end"].get("dateTime", item["end"].get("date"))
        events.append({
            "id": item.get("id"),
            "summary": item.get("summary", "(no title)"),
            "start": start,
            "end": end,
            "allDay": "date" in item["start"],
            "htmlLink": item.get("htmlLink"),
        })

    return events


if __name__ == "__main__":
    interactive = "--auth" in sys.argv[1:]
    _lock = acquire_lock()

    try:
        credentials = get_credentials(interactive)
        print(json.dumps({"events": fetch_events(credentials)}))
    except SystemExit:
        raise
    except Exception as e:
        print(json.dumps({"events": [], "error": str(e)}))
        sys.exit(1)
