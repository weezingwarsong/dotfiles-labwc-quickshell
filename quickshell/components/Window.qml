import QtQuick
import Quickshell.Io

FocusScope {
    id: root

    property var    ws1Windows:  []
    property var    ws2Windows:  []
    property string activeWindow: ""
    property int    selectedFlat: 0

    signal windowFocused()

    readonly property int _gap: Math.round(Screen.height * 0.01)

    readonly property var filteredWs1: ws1Windows.filter(function(w) {
        return filterInput.text === "" || w.toLowerCase().indexOf(filterInput.text.toLowerCase()) >= 0
    })
    readonly property var filteredWs2: ws2Windows.filter(function(w) {
        return filterInput.text === "" || w.toLowerCase().indexOf(filterInput.text.toLowerCase()) >= 0
    })

    readonly property int totalSelectable: filteredWs1.length + filteredWs2.length

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 24 + _gap + switchPanel.implicitHeight

    Component.onCompleted: Qt.callLater(function() { filterInput.forceActiveFocus() })

    function _titleFor(windowStr) {
        var sep = windowStr.indexOf(": ")
        return sep >= 0 ? windowStr.substring(sep + 2) : windowStr
    }

    function focusSelected() {
        if (selectedFlat < filteredWs1.length) {
            _doFocus(filteredWs1[selectedFlat])
        } else {
            var i = selectedFlat - filteredWs1.length
            if (i < filteredWs2.length) _doFocus(filteredWs2[i])
        }
    }

    function _doFocus(windowStr) {
        var sep = windowStr.indexOf(": ")
        var appId = sep >= 0 ? windowStr.substring(0, sep) : windowStr
        var title = sep >= 0 ? windowStr.substring(sep + 2) : ""
        focusProcess.command = ["wlrctl", "toplevel", "focus",
                                "app_id:" + appId, "title:" + title]
        focusProcess.running = true
        root.windowFocused()
    }

    // ── Pill ────────────────────────────────────────────────────────────────
    Rectangle {
        id: pill
        width: parent.width; height: 24
        color: Style.rectMainBg
        border.width: Style.rectBorderWidth; border.color: Style.rectMainBorder

        Text {
            anchors.centerIn: parent
            text: "Window"
            color: Style.textHeaderHighlight
            font.family: Style.fontFamily; font.pointSize: Style.fontSize
        }
    }

    // ── Switch panel ────────────────────────────────────────────────────────
    Rectangle {
        id: switchPanel
        anchors.top: pill.bottom; anchors.topMargin: root._gap
        width: parent.width
        color: Style.rectNormalBg
        border.width: Style.rectBorderWidth; border.color: Style.rectNormalBorder
        implicitHeight: col.implicitHeight + 16

        Column {
            id: col
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 8; leftMargin: 8; rightMargin: 8
            }
            spacing: 4

            // Filter input
            Rectangle {
                width: parent.width; height: 28
                color: Style.rectButtonBg
                border.width: Style.rectBorderWidth; border.color: Style.rectButtonBorder

                Text {
                    anchors.fill: parent; anchors.leftMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: "Filter…"
                    color: Style.textBodyLow
                    font.family: Style.fontFamily; font.pointSize: Style.fontSize
                    visible: filterInput.text.length === 0
                }

                TextInput {
                    id: filterInput
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    color: Style.textBodyNormal
                    font.family: Style.fontFamily; font.pointSize: Style.fontSize
                    selectionColor: Style.textBodyHighlight

                    onTextChanged: root.selectedFlat = 0

                    Keys.priority: Keys.BeforeItem
                    Keys.onUpPressed:     function(event) { if (root.selectedFlat > 0) root.selectedFlat--; event.accepted = true }
                    Keys.onDownPressed:   function(event) { if (root.selectedFlat < root.totalSelectable - 1) root.selectedFlat++; event.accepted = true }
                    Keys.onReturnPressed: function(event) { root.focusSelected(); event.accepted = true }
                }
            }

            // ── Workspace 1 group ──────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 0
                visible: root.filteredWs1.length > 0

                Item {
                    width: parent.width; height: 20
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                        height: 1; color: Style.rectMainBorder
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "1"
                        color: Style.textBodyLow
                        font.family: Style.fontFamily; font.pointSize: Style.fontSize
                    }
                }

                Repeater {
                    model: root.filteredWs1
                    Rectangle {
                        required property string modelData
                        required property int index
                        property bool isHovered: false
                        readonly property bool isActive: modelData === root.activeWindow
                        readonly property bool isSelected: root.selectedFlat === index

                        width: parent.width; height: 22
                        color: isSelected ? Style.textBodyHighlight
                             : isHovered  ? Style.rectButtonBg
                             :              "transparent"

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: { parent.isHovered = true; root.selectedFlat = index }
                            onExited:  parent.isHovered = false
                            onClicked: root._doFocus(modelData)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left;  anchors.leftMargin: 6
                            anchors.right: parent.right; anchors.rightMargin: 6
                            text: root._titleFor(modelData)
                            color: isSelected ? "#2E3440"
                                 : isActive   ? Style.textBodyLow
                                 :              Style.textBodyNormal
                            font.family: Style.fontFamily; font.pointSize: Style.fontSize
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // ── Workspace 2 group ──────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 0
                visible: root.filteredWs2.length > 0

                Item {
                    width: parent.width; height: 20
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                        height: 1; color: Style.rectMainBorder
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "2"
                        color: Style.textBodyLow
                        font.family: Style.fontFamily; font.pointSize: Style.fontSize
                    }
                }

                Repeater {
                    model: root.filteredWs2
                    Rectangle {
                        required property string modelData
                        required property int index
                        property bool isHovered: false
                        readonly property bool isActive: modelData === root.activeWindow
                        readonly property bool isSelected: root.selectedFlat === root.filteredWs1.length + index

                        width: parent.width; height: 22
                        color: isSelected ? Style.textBodyHighlight
                             : isHovered  ? Style.rectButtonBg
                             :              "transparent"

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: {
                                parent.isHovered = true
                                root.selectedFlat = root.filteredWs1.length + index
                            }
                            onExited:  parent.isHovered = false
                            onClicked: root._doFocus(modelData)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left;  anchors.leftMargin: 6
                            anchors.right: parent.right; anchors.rightMargin: 6
                            text: root._titleFor(modelData)
                            color: isSelected ? "#2E3440"
                                 : isActive   ? Style.textBodyLow
                                 :              Style.textBodyNormal
                            font.family: Style.fontFamily; font.pointSize: Style.fontSize
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    Process {
        id: focusProcess
    }
}
