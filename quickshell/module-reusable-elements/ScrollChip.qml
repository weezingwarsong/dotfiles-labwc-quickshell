import QtQuick

Rectangle {
    id: root

    // ── Variant ───────────────────────────────────────────────────────────────
    property string variant: "value"   // "value" | "bar"

    // ── Value variant ─────────────────────────────────────────────────────────
    property string text: ""           // display text e.g. "20px"

    // ── Bar variant ───────────────────────────────────────────────────────────
    property real   value: 0.0         // fill proportion 0.0–1.0
    property string label: ""          // text shown when not hovered
    property string glyph: ""          // optional prefix (emoji / nerd glyph)
    property bool   muted: false       // dims fill, accents border

    // ── Signals ───────────────────────────────────────────────────────────────
    signal scrolled(real delta)        // +1 or -1 from wheel direction
    signal clicked()
    signal rightClicked()

    // ── Sizing ────────────────────────────────────────────────────────────────
    // value: content-driven, min 24, cap 300
    // bar:   caller sets Layout.fillWidth: true
    implicitWidth:  variant === "value"
        ? Math.min(Math.max(_valueText.implicitWidth + Style.panelElementHpadding, 24), 300)
        : 0
    implicitHeight: Style.buttonHeight

    // ── Visuals ───────────────────────────────────────────────────────────────
    radius:       Style.panelElementRadius
    clip:         true
    border.width: Style.elementBorderWidth
    border.color: (variant === "bar" && root.muted) ? Style.accentColor : Style.borderSoftColor

    color: {
        if (variant === "bar") return _hover.hovered ? Style.panelBgColor : Style.surfaceMidColor
        return Style.surfaceLowColor
    }

    // ── Bar fill (hovered) ────────────────────────────────────────────────────
    Rectangle {
        visible:          root.variant === "bar" && _hover.hovered
        width:            parent.width * Math.max(0, Math.min(1, root.value))
        height:           parent.height
        color:            root.muted ? Style.surfaceLowColor : Style.accentBgColor
        opacity:          0.6
        topLeftRadius:    Style.panelElementRadius
        bottomLeftRadius: Style.panelElementRadius
        topRightRadius:    root.value >= 1.0 ? Style.panelElementRadius : 0
        bottomRightRadius: root.value >= 1.0 ? Style.panelElementRadius : 0
    }

    // ── Bar label ─────────────────────────────────────────────────────────────
    Row {
        anchors {
            left: parent.left; right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 8; rightMargin: 8
        }
        spacing: 6
        visible: root.variant === "bar"

        Text {
            visible:                root.glyph !== ""
            text:                   root.glyph
            font.pixelSize:         Style.fontSizeBody
            color:                  root.muted ? Style.textMuted : Style.textSecondary
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            width:                  parent.width - (root.glyph !== "" ? 20 : 0)
            text:                   root.muted ? "MUTED" : root.label
            color:                  root.muted ? Style.textMuted : Style.textSecondary
            font.family:            Style.fontMono
            font.pixelSize:         Style.fontSizeBody
            elide:                  Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ── Value text ────────────────────────────────────────────────────────────
    Text {
        id: _valueText
        anchors.centerIn: parent
        visible:        root.variant === "value"
        text:           root.text
        color:          Style.textNormal
        font.family:    Style.fontMono
        font.pixelSize: Style.fontSizeBody
    }

    // ── Interaction ───────────────────────────────────────────────────────────
    HoverHandler {
        id: _hover
        cursorShape: root.variant === "value" ? Qt.SizeVerCursor : Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.rightClicked()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            root.scrolled(event.angleDelta.y > 0 ? 1 : -1)
            event.accepted = true
        }
    }
}
