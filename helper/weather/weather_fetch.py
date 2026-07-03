#!/usr/bin/env python3
# Fetches current + today's high/low weather and prints one JSON object to
# stdout: {"temp": .., "high": .., "low": .., "condition": "...", "icon": ".."}.
# `icon` is a Nerd Font codepoint (hex string, no "0x"/"\u" prefix) from the
# nf-weather set — Calendar.qml turns it into a glyph with
# String.fromCharCode(parseInt(icon, 16)). Stdlib only — no extra pip
# dependency for a one-shot poll like this.
#
# Location is auto-detected via IP geolocation (ipapi.co, keyless) and
# cached at ~/.config/weather-quickshell/location.json for 24h, since an
# IP's location rarely changes and the free geolocation tier is meant for
# occasional lookups, not a hit every quickshell poll.
#
# Weather itself comes from Open-Meteo (open-source, keyless, no rate-limit
# registration needed) — see https://open-meteo.com/.
#
# On any failure (offline, geolocation down, Open-Meteo down) this still
# prints valid JSON with null fields, so quickshell's JSON.parse never
# throws — same graceful-degrade contract as gcal_fetch.py.

import json
import time
import urllib.request
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "weather-quickshell"
LOCATION_CACHE = CONFIG_DIR / "location.json"
LOCATION_CACHE_TTL_SECS = 24 * 60 * 60
HTTP_TIMEOUT_SECS = 10

# WMO weather codes (used by Open-Meteo) — condensed to short display labels.
WMO_CONDITIONS = {
    0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Rime fog",
    51: "Light drizzle", 53: "Drizzle", 55: "Dense drizzle",
    56: "Freezing drizzle", 57: "Freezing drizzle",
    61: "Light rain", 63: "Rain", 65: "Heavy rain",
    66: "Freezing rain", 67: "Freezing rain",
    71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
    80: "Rain showers", 81: "Rain showers", 82: "Violent showers",
    85: "Snow showers", 86: "Snow showers",
    95: "Thunderstorm", 96: "Thunderstorm + hail", 99: "Thunderstorm + hail",
}

# WMO code -> (day icon, night icon), Nerd Font nf-weather codepoints.
# Verified against the canonical glyphnames.json from ryanoasis/nerd-fonts —
# the nerdfonts.com cheat-sheet filter export this was sourced from had the
# day/night rows misaligned against their codepoints (nearly every entry off
# by a few rows), so these were looked up by name individually rather than
# trusting that table.
WMO_ICONS = {
    0:  ("e30d", "e32b"),  # day_sunny / night_clear
    1:  ("e30c", "e37b"),  # day_sunny_overcast / night_partly_cloudy
    2:  ("e302", "e37e"),  # day_cloudy / night_alt_cloudy
    3:  ("e33d", "e33d"),  # cloud (overcast, no sun/moon either way)
    45: ("e303", "e346"),  # day_fog / night_fog
    48: ("e303", "e346"),
    51: ("e30b", "e328"),  # day_sprinkle / night_alt_sprinkle
    53: ("e30b", "e328"),
    55: ("e30b", "e328"),
    56: ("e3aa", "e3ac"),  # day_sleet / night_alt_sleet (freezing precip)
    57: ("e3aa", "e3ac"),
    61: ("e308", "e325"),  # day_rain / night_alt_rain
    63: ("e308", "e325"),
    65: ("e308", "e325"),
    66: ("e3aa", "e3ac"),
    67: ("e3aa", "e3ac"),
    71: ("e30a", "e327"),  # day_snow / night_alt_snow
    73: ("e30a", "e327"),
    75: ("e30a", "e327"),
    77: ("e30a", "e327"),
    80: ("e309", "e326"),  # day_showers / night_alt_showers
    81: ("e309", "e326"),
    82: ("e309", "e326"),
    85: ("e30a", "e327"),
    86: ("e30a", "e327"),
    95: ("e30f", "e32a"),  # day_thunderstorm / night_alt_thunderstorm
    96: ("e30f", "e32a"),
    99: ("e30f", "e32a"),
}


def fetch_json(url):
    with urllib.request.urlopen(url, timeout=HTTP_TIMEOUT_SECS) as resp:
        return json.loads(resp.read())


def get_location():
    try:
        cached = json.loads(LOCATION_CACHE.read_text())
        if time.time() - cached["resolved_at"] < LOCATION_CACHE_TTL_SECS:
            return cached["lat"], cached["lon"]
    except (OSError, json.JSONDecodeError, KeyError):
        pass

    data = fetch_json("https://ipapi.co/json/")
    lat, lon = data["latitude"], data["longitude"]

    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    LOCATION_CACHE.write_text(json.dumps({"lat": lat, "lon": lon, "resolved_at": time.time()}))
    return lat, lon


def main():
    try:
        lat, lon = get_location()
        url = (
            "https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lon}"
            "&current=temperature_2m,weather_code,is_day"
            "&daily=temperature_2m_max,temperature_2m_min"
            "&temperature_unit=celsius&timezone=auto&forecast_days=1"
        )
        data = fetch_json(url)
        code = data["current"]["weather_code"]
        day_icon, night_icon = WMO_ICONS.get(code, ("e33d", "e33d"))
        print(json.dumps({
            "temp":      round(data["current"]["temperature_2m"]),
            "high":      round(data["daily"]["temperature_2m_max"][0]),
            "low":       round(data["daily"]["temperature_2m_min"][0]),
            "condition": WMO_CONDITIONS.get(code, "Unknown"),
            "icon":      day_icon if data["current"]["is_day"] else night_icon,
        }))
    except Exception:
        print(json.dumps({"temp": None, "high": None, "low": None, "condition": None, "icon": None}))


if __name__ == "__main__":
    main()
