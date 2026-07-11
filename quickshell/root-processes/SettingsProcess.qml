import QtQuick
import QtCore
import Quickshell.Io

Item {
    id: root

    signal googleDisconnected()

    // ── Persistence ───────────────────────────────────────────────────────────
    Settings {
        id: _store
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/pillbox.conf"
        property bool   googleConnected: true
        property string locationMode:    "auto"   // "auto" | "manual"
        property string locationString:  ""
    }

    // ── Public (read-only) ────────────────────────────────────────────────────

    readonly property bool   googleConnected: _store.googleConnected
    readonly property string locationMode:    _store.locationMode
    readonly property string locationString:  _store.locationString
    property string          googleEmail:     ""

    // ── Email fetch ───────────────────────────────────────────────────────────

    Process {
        id: _emailProc
        command: ["gcal-fetch", "--email"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var obj = JSON.parse(line)
                    if (obj.email) root.googleEmail = obj.email
                } catch(e) {}
            }
        }
        onExited: function(code) {
            if (code !== 0) console.log("[SettingsProcess] gcal-fetch --email exited:", code)
        }
    }

    function _fetchEmail() {
        if (_store.googleConnected) _emailProc.running = true
    }

    // ── Setters ───────────────────────────────────────────────────────────────

    function setLocationMode(val)    { _store.locationMode    = val }
    function setLocationString(val)  { _store.locationString  = val }

    // ── Google account management ─────────────────────────────────────────────

    // Called by SettingsPanel after gcal-fetch --revoke completes.
    function disconnect() {
        _store.googleConnected = false
        root.googleEmail = ""
        googleDisconnected()
        console.log("[SettingsProcess] Google account disconnected")
    }

    // Called by SettingsPanel when user initiates Connect / Re-authenticate.
    // Optimistic — processes resume fetching immediately; any auth failure
    // surfaces via CalendarProcess/TasksProcess.lastError.
    function reconnect() {
        _store.googleConnected = true
        _fetchEmail()
        console.log("[SettingsProcess] Google account reconnected (optimistic)")
    }

    Component.onCompleted: {
        console.log(
            "[SettingsProcess] started | googleConnected:", _store.googleConnected,
            "| locationMode:", _store.locationMode,
            "| locationString:", _store.locationString || "(none)")
        _fetchEmail()
    }
}
