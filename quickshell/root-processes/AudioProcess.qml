import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    // Device names from PipeWire (works fine)
    readonly property string sinkName:   Pipewire.defaultAudioSink
                                         ? _nodeName(Pipewire.defaultAudioSink) : "—"
    readonly property string sourceName: Pipewire.defaultAudioSource
                                         ? _nodeName(Pipewire.defaultAudioSource) : "—"

    // Volume & mute from wpctl polling (PwNodeAudio.volume is not writable via QML)
    property real   sinkVolume:   0
    property bool   sinkMuted:    false
    property real   sourceVolume: 0
    property bool   sourceMuted:  false

    function setSinkVolume(delta) {
        var clamped = Math.min(1.0, Math.max(0.0, sinkVolume + delta))
        _sinkCmd(Math.round(clamped * 100) + "%")
    }
    function setSourceVolume(delta) {
        var clamped = Math.min(1.0, Math.max(0.0, sourceVolume + delta))
        _sourceCmd(Math.round(clamped * 100) + "%")
    }
    function toggleSinkMute()       { _sinkCmd(null) }
    function toggleSourceMute()     { _sourceCmd(null) }

    function poll() {
        if (!_sinkPoll.running)   _sinkPoll.running   = true
        if (!_sourcePoll.running) _sourcePoll.running = true
    }

    function _sinkCmd(volArg) {
        if (_sinkOp.running) return
        _sinkOp.command = volArg !== null
            ? ["wpctl", "set-volume",  "@DEFAULT_AUDIO_SINK@", volArg]
            : ["wpctl", "set-mute",    "@DEFAULT_AUDIO_SINK@", "toggle"]
        _sinkOp.running = true
    }
    function _sourceCmd(volArg) {
        if (_sourceOp.running) return
        _sourceOp.command = volArg !== null
            ? ["wpctl", "set-volume",  "@DEFAULT_AUDIO_SOURCE@", volArg]
            : ["wpctl", "set-mute",    "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        _sourceOp.running = true
    }
    function _nodeName(n) {
        return n.nickname !== "" ? n.nickname : n.description !== "" ? n.description : n.name
    }

    // ── Poll timer ────────────────────────────────────────────────────────────
    Timer { interval: 3000; repeat: true; running: true; onTriggered: root.poll() }
    Component.onCompleted: poll()

    // ── Operation processes ───────────────────────────────────────────────────
    Process { id: _sinkOp;   onExited: Qt.callLater(root.poll) }
    Process { id: _sourceOp; onExited: Qt.callLater(root.poll) }

    // ── Poll processes ────────────────────────────────────────────────────────
    Process {
        id: _sinkPoll
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/Volume:\s+([\d.]+)(\s+\[MUTED\])?/)
                if (!m) return
                root.sinkVolume = parseFloat(m[1])
                root.sinkMuted  = !!m[2]
            }
        }
    }

    Process {
        id: _sourcePoll
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/Volume:\s+([\d.]+)(\s+\[MUTED\])?/)
                if (!m) return
                root.sourceVolume = parseFloat(m[1])
                root.sourceMuted  = !!m[2]
            }
        }
    }
}
