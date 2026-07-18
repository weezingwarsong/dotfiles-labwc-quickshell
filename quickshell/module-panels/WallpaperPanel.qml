import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import QtQuick.Effects

Item {
    id: root
    focus: true
    Component.onCompleted: forceActiveFocus()

    property var wallpaperProcess: null

    implicitHeight: _col.implicitHeight

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Tab:
            root._tab = root._tab === "color" ? "image" : root._tab === "image" ? "video" : "color"
            event.accepted = true; break
        default:
            event.accepted = false
        }
    }

    // ── Constants ─────────────────────────────────────────────────────────────
    readonly property int _spacing: 4
    readonly property int _swatchW: Math.floor((width - 2 * Style.panelCardHpadding - 5 * _spacing) / 6)

    // ── Tabs ──────────────────────────────────────────────────────────────────
    property string _tab:            "color"
    property bool   _colorCollapsed: false

    // ── Color swatches ────────────────────────────────────────────────────────
    readonly property var _swatches: [
        { hex: "#282C34", name: "Dark Slate / One Dark" },
        { hex: "#1E1E2E", name: "Catppuccin Mocha Base" },
        { hex: "#2B303A", name: "Charcoal Navy" },
        { hex: "#1A1B26", name: "Tokyo Night Dark" },
        { hex: "#2F343F", name: "Arc Dark Gray" },
        { hex: "#363B4E", name: "Muted Indigo" },
        { hex: "#3B4252", name: "Nord Dark Blue" },
        { hex: "#2D3748", name: "Cool Graphite" },
        { hex: "#3C3836", name: "Gruvbox Dark Gray" },
        { hex: "#2A323D", name: "Steel Blue Gray" },
        { hex: "#434C5E", name: "Slate Slate" },
        { hex: "#4A5240", name: "Muted Olive" },
        { hex: "#3A4638", name: "Dark Sage" },
        { hex: "#5B4B49", name: "Dusty Rose Brown" },
        { hex: "#4C3A48", name: "Muted Plum" },
        { hex: "#3E4A5B", name: "Storm Cloud Blue" },
        { hex: "#5C6B73", name: "Ocean Slate" },
        { hex: "#4A5568", name: "Slate Neutral" },
        { hex: "#524B66", name: "Dusk Purple" },
        { hex: "#6A5D52", name: "Warm Taupe" },
        { hex: "#556B2F", name: "Muted Moss" },
        { hex: "#38424D", name: "Deep Twilight" },
        { hex: "#2F3E46", name: "Dark Forest Slate" },
        { hex: "#1F232A", name: "Obsidian Black" }
    ]

    // ── Carousel helpers ──────────────────────────────────────────────────────
    function _findImageIdx() {
        if (!root.wallpaperProcess || root.wallpaperProcess.sourceType !== "image") return 0
        var files = root.wallpaperProcess.imageFiles
        for (var i = 0; i < files.length; i++)
            if (files[i].path === root.wallpaperProcess.currentPath) return i
        return 0
    }

    function _findVideoIdx() {
        if (!root.wallpaperProcess || root.wallpaperProcess.sourceType !== "video") return 0
        var files = root.wallpaperProcess.videoFiles
        for (var i = 0; i < files.length; i++)
            if (files[i].path === root.wallpaperProcess.currentPath) return i
        return 0
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 10

        PanelTabBar {
            labels:   ["Color", "Image", "Video"]
            selected: root._tab === "color" ? 0 : root._tab === "image" ? 1 : 2
            onToggled: (i) => root._tab = (i === 0 ? "color" : i === 1 ? "image" : "video")
        }

        // ── Color tab ─────────────────────────────────────────────────────────
        PanelCard {
            visible: root._tab === "color"
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                SectionHeader {
                    Layout.fillWidth: true
                    text:      "Background Color"
                    tooltip:   "Solid color wallpaper"
                    collapsed: root._colorCollapsed
                    onToggled: root._colorCollapsed = !root._colorCollapsed
                }

                Item {
                    Layout.fillWidth: true; clip: true
                    Layout.preferredHeight: !root._colorCollapsed ? _colorRows.implicitHeight + 8 : 0
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: _colorRows
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                        spacing: 8

                        Grid {
                            columns: 6; spacing: root._spacing

                            Repeater {
                                model: root._swatches
                                Rectangle {
                                    required property var modelData
                                    width:  root._swatchW; height: width
                                    radius: Style.panelElementRadius; color: modelData.hex

                                    readonly property bool _active:
                                        root.wallpaperProcess
                                        && root.wallpaperProcess.sourceType === "color"
                                        && root.wallpaperProcess.currentColor === modelData.hex

                                    border.width: (_active || _swatchHover.hovered) ? 2 : 1
                                    border.color: (_active || _swatchHover.hovered) ? Style.accentColor : Style.borderFaintColor

                                    Rectangle {
                                        anchors.fill: parent; radius: parent.radius
                                        color: "white"; opacity: _swatchHover.hovered ? 0.12 : 0
                                        Behavior on opacity { NumberAnimation { duration: 100 } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible:        parent._active
                                        text:           ""
                                        font.family:    Style.fontNerd
                                        font.pixelSize: Math.round(parent.width * 0.45)
                                        color:          "white"
                                        style:          Text.Outline
                                        styleColor:     "#80000000"
                                    }

                                    HoverHandler { id: _swatchHover }
                                    QQC.ToolTip { visible: _swatchHover.hovered; text: modelData.name; delay: 400 }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.wallpaperProcess) root.wallpaperProcess.setColor(modelData.hex)
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.wallpaperProcess && root.wallpaperProcess.lastError !== ""
                                     && root.wallpaperProcess.sourceType === "color"
                            text:    root.wallpaperProcess ? root.wallpaperProcess.lastError : ""
                            color: Style.textCritical; font.family: Style.fontMono; font.pixelSize: Style.fontSizeSubtle
                        }
                    }
                }
            }
        }

        // ── Image tab ─────────────────────────────────────────────────────────
        Item {
            id: _imageTab
            visible: root._tab === "image"
            Layout.fillWidth: true
            Layout.preferredHeight: _heroH + 4 + Style.fontSizeSubtle

            property bool _ready:       false
            property bool _animEnabled: false
            property real _scrollPos:   0

            // Ratios chosen so 2×sideW + heroW + 2×gap ≤ width (no container clip needed)
            readonly property int _heroW: Math.round(width * 0.55)
            readonly property int _sideW: Math.round(width * 0.18)
            readonly property int _heroH: Math.round(_heroW * 0.65)
            readonly property int _step:  Math.round(_heroW / 2 + _sideW / 2 + 6)

            Behavior on _scrollPos {
                enabled: _imageTab._animEnabled
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            // Reset scroll to current wallpaper index, no animation, then re-enable
            function _reset() {
                _animEnabled = false
                _ready       = false
                _scrollPos   = root._findImageIdx()
                Qt.callLater(function() { _animEnabled = true; _ready = true })
            }

            onVisibleChanged: { if (visible) _reset() }

            // ── Carousel area ─────────────────────────────────────────────────
            Item {
                id: _imgArea
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: _imageTab._heroH

                Text {
                    visible: !root.wallpaperProcess || root.wallpaperProcess.imageFiles.length === 0
                    anchors.centerIn: parent
                    text:  root.wallpaperProcess && root.wallpaperProcess.wallpaperDir !== ""
                           ? "No images found" : "Scan a directory in Settings"
                    color: Style.textMuted; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    width: parent.width
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        event.accepted = true
                        if (!_imageTab._ready) return
                        var count = root.wallpaperProcess ? root.wallpaperProcess.imageFiles.length : 0
                        if (count === 0) return
                        var cur  = Math.round(_imageTab._scrollPos)
                        var next = Math.max(0, Math.min(count - 1, cur + (event.angleDelta.y < 0 ? 1 : -1)))
                        if (next === cur) return
                        _imageTab._scrollPos = next
                        root.wallpaperProcess.setImage(root.wallpaperProcess.imageFiles[next].path)
                    }
                }

                Repeater {
                    model: root.wallpaperProcess ? root.wallpaperProcess.imageFiles : []

                    Item {
                        required property var modelData
                        required property int index

                        // Continuous distance from center; drives width and x simultaneously
                        readonly property real _dist: index - _imageTab._scrollPos
                        readonly property real _absD: Math.min(1.0, Math.abs(_dist))
                        readonly property real _w:    _imageTab._heroW + (_imageTab._sideW - _imageTab._heroW) * _absD

                        readonly property bool _active:
                            root.wallpaperProcess
                            && root.wallpaperProcess.sourceType === "image"
                            && root.wallpaperProcess.currentPath === modelData.path

                        x:       _imgArea.width / 2 + _dist * _imageTab._step - _w / 2
                        y:       0
                        width:   _w
                        height:  _imageTab._heroH
                        visible: Math.abs(index - Math.round(_imageTab._scrollPos)) <= 1
                        opacity: Math.max(0.0, _absD <= 1.0 ? 1.0 - _absD * 0.3 : (1.5 - _absD) * 1.4)

                        // Source + mask are hidden; MultiEffect composites them
                        Image {
                            id: _imgSrc
                            anchors.fill: parent
                            visible:      false; layer.enabled: true
                            source:       "file://" + modelData.path
                            fillMode:     Image.PreserveAspectCrop
                            asynchronous: true; smooth: true
                        }
                        Rectangle {
                            id: _imgMask
                            anchors.fill: parent
                            radius: Style.pillRadius; color: "white"
                            visible: false; layer.enabled: true
                        }
                        MultiEffect {
                            anchors.fill:     parent
                            source:           _imgSrc
                            maskEnabled:      true
                            maskSource:       _imgMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin:  1.0
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Style.pillRadius; color: "transparent"
                            border.width: _active ? 2 : 0
                            border.color: Style.accentColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                _imageTab._scrollPos = index
                                if (root.wallpaperProcess)
                                    root.wallpaperProcess.setImage(modelData.path)
                            }
                        }
                    }
                }
            }

            // Filename of centered item
            Text {
                anchors { left: parent.left; right: parent.right; top: _imgArea.bottom; topMargin: 4 }
                property int _idx: Math.round(_imageTab._scrollPos)
                text: (root.wallpaperProcess && _idx >= 0 && _idx < root.wallpaperProcess.imageFiles.length)
                      ? root.wallpaperProcess.imageFiles[_idx].name : ""
                color:               Style.textMuted
                font.family:         Style.fontMono
                font.pixelSize:      Style.fontSizeSubtle
                horizontalAlignment: Text.AlignHCenter
                elide:               Text.ElideRight
            }
        }

        // ── Video tab ─────────────────────────────────────────────────────────
        Item {
            id: _videoTab
            visible: root._tab === "video"
            Layout.fillWidth: true
            Layout.preferredHeight: _heroH + 4 + Style.fontSizeSubtle

            property bool _ready:       false
            property bool _animEnabled: false
            property real _scrollPos:   0

            readonly property int _heroW: Math.round(width * 0.55)
            readonly property int _sideW: Math.round(width * 0.18)
            readonly property int _heroH: Math.round(_heroW * 0.65)
            readonly property int _step:  Math.round(_heroW / 2 + _sideW / 2 + 6)

            Behavior on _scrollPos {
                enabled: _videoTab._animEnabled
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            function _reset() {
                _animEnabled = false
                _ready       = false
                _scrollPos   = root._findVideoIdx()
                Qt.callLater(function() { _animEnabled = true; _ready = true })
            }

            onVisibleChanged: { if (visible) _reset() }

            // ── Carousel area ─────────────────────────────────────────────────
            Item {
                id: _vidArea
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: _videoTab._heroH

                Text {
                    visible: !root.wallpaperProcess || root.wallpaperProcess.videoFiles.length === 0
                    anchors.centerIn: parent
                    text:  root.wallpaperProcess && root.wallpaperProcess.wallpaperDir !== ""
                           ? "No videos found" : "Scan a directory in Settings"
                    color: Style.textMuted; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    width: parent.width
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        event.accepted = true
                        if (!_videoTab._ready) return
                        var count = root.wallpaperProcess ? root.wallpaperProcess.videoFiles.length : 0
                        if (count === 0) return
                        var cur  = Math.round(_videoTab._scrollPos)
                        var next = Math.max(0, Math.min(count - 1, cur + (event.angleDelta.y < 0 ? 1 : -1)))
                        if (next === cur) return
                        _videoTab._scrollPos = next
                        root.wallpaperProcess.setVideo(root.wallpaperProcess.videoFiles[next].path)
                    }
                }

                Repeater {
                    model: root.wallpaperProcess ? root.wallpaperProcess.videoFiles : []

                    Item {
                        required property var modelData
                        required property int index

                        readonly property real _dist: index - _videoTab._scrollPos
                        readonly property real _absD: Math.min(1.0, Math.abs(_dist))
                        readonly property real _w:    _videoTab._heroW + (_videoTab._sideW - _videoTab._heroW) * _absD

                        readonly property bool _active:
                            root.wallpaperProcess
                            && root.wallpaperProcess.sourceType === "video"
                            && root.wallpaperProcess.currentPath === modelData.path

                        readonly property bool _hasThumb:
                            root.wallpaperProcess
                            && !!root.wallpaperProcess.thumbsReady[modelData.path]

                        x:       _vidArea.width / 2 + _dist * _videoTab._step - _w / 2
                        y:       0
                        width:   _w
                        height:  _videoTab._heroH
                        visible: Math.abs(index - Math.round(_videoTab._scrollPos)) <= 1
                        opacity: Math.max(0.0, _absD <= 1.0 ? 1.0 - _absD * 0.3 : (1.5 - _absD) * 1.4)

                        // Fallback background + placeholder icon (always present)
                        Rectangle {
                            anchors.fill: parent
                            radius: Style.pillRadius; color: Style.surfaceMidColor

                            Text {
                                anchors.centerIn: parent
                                visible:        !_hasThumb
                                text:           String.fromCodePoint(0xf040a)
                                font.family:    Style.fontNerd
                                font.pixelSize: Math.round(_w * 0.38)
                                color:          _active ? Style.accentColor : Style.textMuted
                            }
                        }
                        // Thumbnail masked to rounded shape (overlays background)
                        Image {
                            id: _vidSrc
                            anchors.fill: parent
                            visible:      false; layer.enabled: true
                            source:       _hasThumb
                                          ? "file://" + root.wallpaperProcess.thumbPath(modelData.path)
                                          : ""
                            fillMode:     Image.PreserveAspectCrop
                            asynchronous: true; smooth: true
                        }
                        Rectangle {
                            id: _vidMask
                            anchors.fill: parent
                            radius: Style.pillRadius; color: "white"
                            visible: false; layer.enabled: true
                        }
                        MultiEffect {
                            anchors.fill:     parent
                            visible:          _hasThumb
                            source:           _vidSrc
                            maskEnabled:      true
                            maskSource:       _vidMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin:  1.0
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Style.pillRadius; color: "transparent"
                            border.width: _active ? 2 : 0
                            border.color: Style.accentColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                _videoTab._scrollPos = index
                                if (root.wallpaperProcess)
                                    root.wallpaperProcess.setVideo(modelData.path)
                            }
                        }
                    }
                }
            }

            // Filename of centered item
            Text {
                anchors { left: parent.left; right: parent.right; top: _vidArea.bottom; topMargin: 4 }
                property int _idx: Math.round(_videoTab._scrollPos)
                text: (root.wallpaperProcess && _idx >= 0 && _idx < root.wallpaperProcess.videoFiles.length)
                      ? root.wallpaperProcess.videoFiles[_idx].name : ""
                color:               Style.textMuted
                font.family:         Style.fontMono
                font.pixelSize:      Style.fontSizeSubtle
                horizontalAlignment: Text.AlignHCenter
                elide:               Text.ElideRight
            }
        }

        // ── Error feedback ────────────────────────────────────────────────────
        Text {
            visible: root.wallpaperProcess && root.wallpaperProcess.lastError !== ""
                     && root.wallpaperProcess.sourceType !== "color"
                     && root._tab !== "color"
            text:    root.wallpaperProcess ? root.wallpaperProcess.lastError : ""
            color:   Style.textCritical
            font.family: Style.fontMono; font.pixelSize: Style.fontSizeSubtle
        }
    }
}
