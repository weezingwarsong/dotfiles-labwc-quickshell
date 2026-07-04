#!/usr/bin/env python3
# Fetches tasks from the user's Google Tasks and prints them as
# one JSON object to stdout: {"tasks": [...]}. Read-only (tasks.readonly scope).
#
# Shares auth state with gcal-fetch at ~/.config/gcal-quickshell/:
# credentials.json (OAuth client) and token.json (cached user token).
# The token must have been issued with both calendar.readonly and tasks.readonly
# scopes — run `gcal-fetch --auth` to re-auth if needed (covers both scopes).
#
# Two modes:
#   gtask-fetch         fetch mode — used by quickshell on a timer.
#   gtask-fetch --auth  interactive mode — re-auth and confirm with a fetch.
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
LOCK_FILE        = CONFIG_DIR / "gtask_fetch.lock"
HTTP_TIMEOUT_SECS = 15
REAUTH_NOTIFY    = Path.home() / ".local/bin/google-auth-notify"
LOG_FILE         = Path("/tmp/pillbox-google.log")


def log_error(error_type, message):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{timestamp}] [gtask-fetch] [{error_type}] {message}\n")
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
        return None


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
            creds = None

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


def fetch_tasks(creds):
    authed_http = AuthorizedHttp(creds, http=httplib2.Http(timeout=HTTP_TIMEOUT_SECS))
    service = build("tasks", "v1", http=authed_http, cache_discovery=False)

    lists_result = service.tasklists().list(maxResults=20).execute(num_retries=2)
    task_lists = lists_result.get("items", [])

    all_tasks = []
    for task_list in task_lists:
        list_id    = task_list["id"]
        list_title = task_list.get("title", "")

        result = service.tasks().list(
            tasklist=list_id,
            maxResults=100,
            showCompleted=True,
            showHidden=False,
            completedMin=(datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=30)).isoformat(),
        ).execute(num_retries=2)

        for item in result.get("items", []):
            # Strip due date to YYYY-MM-DD (Google returns RFC 3339 midnight UTC)
            due = None
            if item.get("due"):
                due = item["due"][:10]

            all_tasks.append({
                "id":        item.get("id"),
                "title":     item.get("title", "(no title)"),
                "status":    item.get("status", "needsAction"),
                "due":       due,
                "notes":     item.get("notes"),
                "listTitle": list_title,
                "listId":    list_id,
            })

    return all_tasks


if __name__ == "__main__":
    interactive = "--auth" in sys.argv[1:]
    _lock = acquire_lock()

    try:
        credentials = get_credentials(interactive)
        print(json.dumps({"tasks": fetch_tasks(credentials)}))
    except SystemExit:
        raise
    except (httplib2.ServerNotFoundError, socket.timeout, OSError) as e:
        log_error("network", str(e))
        print(json.dumps({"tasks": []}))
        sys.exit(1)
    except Exception as e:
        log_error("error", str(e))
        print(json.dumps({"tasks": [], "error": str(e)}))
        sys.exit(1)
