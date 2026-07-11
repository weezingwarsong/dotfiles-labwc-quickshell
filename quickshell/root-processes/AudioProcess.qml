import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root

    // ── Default nodes (reactive — update when PipeWire default changes) ────────
    readonly property var sink:   Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool ready: Pipewire.ready

    // ── Convenience pass-throughs ─────────────────────────────────────────────
    readonly property real   sinkVolume: sink   ? sink.audio.volume  : 0
    readonly property bool   sinkMuted:  sink   ? sink.audio.muted   : false
    readonly property string sinkName:   sink   ? _nodeName(sink)    : "—"

    readonly property real   sourceVolume: source ? source.audio.volume : 0
    readonly property bool   sourceMuted:  source ? source.audio.muted  : false
    readonly property string sourceName:   source ? _nodeName(source)   : "—"

    // ── Public API ────────────────────────────────────────────────────────────

    function setSinkVolume(v)    { if (sink)   sink.audio.volume  = Math.max(0, Math.min(1, v)) }
    function toggleSinkMute()    { if (sink)   sink.audio.muted   = !sink.audio.muted }

    function setSourceVolume(v)  { if (source) source.audio.volume = Math.max(0, Math.min(1, v)) }
    function toggleSourceMute()  { if (source) source.audio.muted  = !source.audio.muted }

    // ── Internal ──────────────────────────────────────────────────────────────

    function _nodeName(node) {
        if (node.nickname  !== "") return node.nickname
        if (node.description !== "") return node.description
        return node.name
    }
}
