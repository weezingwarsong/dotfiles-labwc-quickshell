#!/usr/bin/env python3
# Fetches events from the user's primary Google Calendar and prints them as
# one JSON object to stdout: {"events": [...]}. Read-only (calendar.readonly
# scope) — the panel's "open in browser" button handles editing.
#
# Auth state lives outside the repo (it's public on GitHub) at
# ~/.config/gcal-quickshell/: credentials.json (OAuth client, from Google
# Cloud Console) and token.json (cached user token, shared with gtask-fetch).
#
# Two modes:
#   gcal-fetch         fetch mode — used by quickshell on a timer. Never
#                       opens a browser; if re-auth is needed, sends a
#                       notification with a "Re-authenticate" action and exits.
#   gcal-fetch --auth  interactive mode — run this by hand (initial setup,
#                       or after the refresh token expires) to do the OAuth
#                       consent flow, then confirms with a fetch.
#
# While the OAuth consent screen is in "Testing" publishing status, Google
# expires the refresh token after 7 days, so fetch mode will periodically
# need a manual `--auth` run. Publishing the app (Audience tab -> Publish
# App) removes that 7-day cap.
#
# Errors are logged to /tmp/pillbox-google.log for easy troubleshooting.

import datetime
import fcntl
import json
import os
import socket
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

import httplib2
from google.auth.exceptions import RefreshError
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_httplib2 import AuthorizedHttp
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = [
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/tasks.readonly",
]
CONFIG_DIR       = Path.home() / ".config" / "gcal-quickshell"
CREDENTIALS_FILE = CONFIG_DIR / "credentials.json"
TOKEN_FILE       = CONFIG_DIR / "token.json"
LOCK_FILE        = CONFIG_DIR / "gcal_fetch.lock"
HTTP_TIMEOUT_SECS = 15
REAUTH_NOTIFY    = Path.home() / ".local/bin/google-auth-notify"
LOG_FILE         = Path("/tmp/pillbox-google.log")


def log_error(error_type, message):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{timestamp}] [gcal-fetch] [{error_type}] {message}\n")
    except OSError:
        pass


def notify_reauth():
    try:
        subprocess.Popen(
            [str(REAUTH_NOTIFY)],
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        log_error("notify", f"google-auth-notify not found at {REAUTH_NOTIFY}")


def acquire_lock():
    # Kept open (and referenced) for the life of the process — the lock
    # releases automatically on exit, including a crash, so there's no
    # stale-lock cleanup to worry about (unlike a PID file).
    lock_file = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)  # another instance is running — skip silently
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
            creds.refresh(Request())
            _write_token(creds)
            return creds
        except RefreshError:
            creds = None  # refresh token itself is dead — needs full reauth

    if not interactive:
        log_error("auth", "re-authorization required — refresh token expired or missing")
        notify_reauth()
        sys.exit(1)

    if not CREDENTIALS_FILE.exists():
        sys.exit(f"error: missing {CREDENTIALS_FILE} — download OAuth client credentials from Google Cloud Console")

    flow = InstalledAppFlow.from_client_secrets_file(str(CREDENTIALS_FILE), SCOPES)
    creds = flow.run_local_server(port=0)
    _write_token(creds)
    return creds


def fetch_events(creds, days_back=90, days_ahead=730, max_results=250):
    # Window covers roughly -3 months to +24 months so the calendar panel's
    # month-navigation UI can color/tooltip event days by filtering this
    # already-cached list client-side, instead of re-fetching per click.
    authed_http = AuthorizedHttp(creds, http=httplib2.Http(timeout=HTTP_TIMEOUT_SECS))
    service = build("calendar", "v3", http=authed_http, cache_discovery=False)

    now = datetime.datetime.now(datetime.timezone.utc)
    time_min = (now - datetime.timedelta(days=days_back)).isoformat()
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
            "id":       item.get("id"),
            "summary":  item.get("summary", "(no title)"),
            "start":    start,
            "end":      end,
            "allDay":   "date" in item["start"],
            "htmlLink": item.get("htmlLink"),
        })

    return events


def fetch_email(creds):
    """Return the user's email by reading the primary calendar's id field."""
    authed_http = AuthorizedHttp(creds, http=httplib2.Http(timeout=HTTP_TIMEOUT_SECS))
    service = build("calendar", "v3", http=authed_http, cache_discovery=False)
    cal = service.calendarList().get(calendarId="primary").execute(num_retries=2)
    return cal.get("id", "")


def revoke_token():
    """Revoke Google OAuth token server-side (best-effort) and delete local token file."""
    creds = _load_cached_credentials()
    if creds:
        token = creds.refresh_token or creds.token
        if token:
            try:
                data = urllib.parse.urlencode({"token": token}).encode()
                req = urllib.request.Request(
                    "https://oauth2.googleapis.com/revoke",
                    data=data,
                    headers={"Content-Type": "application/x-www-form-urlencoded"},
                )
                urllib.request.urlopen(req, timeout=5)
            except Exception as e:
                log_error("revoke", f"server-side revocation failed (token deleted locally anyway): {e}")
    TOKEN_FILE.unlink(missing_ok=True)
    print(json.dumps({"revoked": True}))


if __name__ == "__main__":
    if "--revoke" in sys.argv[1:]:
        revoke_token()
        sys.exit(0)

    if "--email" in sys.argv[1:]:
        _lock = acquire_lock()
        try:
            credentials = get_credentials(interactive=False)
            print(json.dumps({"email": fetch_email(credentials)}))
        except SystemExit:
            raise
        except Exception as e:
            log_error("email", str(e))
            print(json.dumps({"email": ""}))
            sys.exit(1)
        sys.exit(0)

    interactive = "--auth" in sys.argv[1:]
    _lock = acquire_lock()

    try:
        credentials = get_credentials(interactive)
        print(json.dumps({"events": fetch_events(credentials)}))
    except SystemExit:
        raise
    except (httplib2.ServerNotFoundError, socket.timeout, OSError) as e:
        log_error("network", str(e))
        print(json.dumps({"events": []}))
        sys.exit(1)
    except Exception as e:
        log_error("error", str(e))
        print(json.dumps({"events": [], "error": str(e)}))
        sys.exit(1)
