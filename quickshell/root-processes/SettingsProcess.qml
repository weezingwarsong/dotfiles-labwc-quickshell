import QtQuick
import QtCore

Item {
    id: root

    signal googleDisconnected()

    // ── Persistence ───────────────────────────────────────────────────────────
    // Qt.labs.settings requires organizationName/applicationName to derive a
    // path automatically; Quickshell doesn't set these. Specify fileName
    // explicitly via StandardPaths so QSettings always has a valid target.
    // QSettings creates the parent directory if it does not exist.

    Settings {
        id: _store
        // QtCore.Settings uses location (url) for a custom file path.
        // StandardPaths returns an absolute path; prepend "file://" to form a valid file URL.
        location: "file://" + StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/pillbox/pillbox.conf"
        property bool   googleConnected: true
        property string locationMode:    "auto"   // "auto" | "manual"
        property string locationString:  ""
    }

    // ── Public (read-only) ────────────────────────────────────────────────────

    readonly property bool   googleConnected: _store.googleConnected
    readonly property string locationMode:    _store.locationMode
    readonly property string locationString:  _store.locationString

    // ── Setters ───────────────────────────────────────────────────────────────

    function setLocationMode(val)    { _store.locationMode    = val }
    function setLocationString(val)  { _store.locationString  = val }

    // ── Google account management ─────────────────────────────────────────────

    // Called by SettingsPanel after gcal-fetch --revoke completes.
    function disconnect() {
        _store.googleConnected = false
        googleDisconnected()
        console.log("[SettingsProcess] Google account disconnected")
    }

    // Called by SettingsPanel when user initiates Connect / Re-authenticate.
    // Optimistic — processes resume fetching immediately; any auth failure
    // surfaces via CalendarProcess/TasksProcess.lastError.
    function reconnect() {
        _store.googleConnected = true
        console.log("[SettingsProcess] Google account reconnected (optimistic)")
    }

    Component.onCompleted: console.log(
        "[SettingsProcess] started | googleConnected:", _store.googleConnected,
        "| locationMode:", _store.locationMode,
        "| locationString:", _store.locationString || "(none)")
}
