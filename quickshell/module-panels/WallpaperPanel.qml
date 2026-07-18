import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

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
        case Qt.Key_N:
        case Qt.Key_B:
            if (root._tab === "image" && root.wallpaperProcess) {
                const count = root.wallpaperProcess.imageFiles.length
                if (count === 0) { event.accepted = false; break }
                const dir  = event.key === Qt.Key_N ? 1 : -1
                const next = Math.max(0, Math.min(count - 1, _carousel.currentIndex + dir))
                if (next === _carousel.currentIndex) { event.accepted = false; break }
                _carousel._direction   = dir
                _carousel.currentIndex = next
                root.wallpaperProcess.setImage(root.wallpaperProcess.imageFiles[next].path)
            } else if (root._tab === "video" && root.wallpaperProcess) {
                const vcount = root.wallpaperProcess.videoFiles.length
                if (vcount === 0) { event.accepted = false; break }
                const vdir  = event.key === Qt.Key_N ? 1 : -1
                const vnext = Math.max(0, Math.min(vcount - 1, _videoCarousel.currentIndex + vdir))
                if (vnext === _videoCarousel.currentIndex) { event.accepted = false; break }
                _videoCarousel._direction   = vdir
                _videoCarousel.currentIndex = vnext
                root.wallpaperProcess.setVideo(root.wallpaperProcess.videoFiles[vnext].path)
            }
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
    property bool   _imageCollapsed: false
    property bool   _videoCollapsed: false

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
        PanelCard {
            visible: root._tab === "image"
            Layout.fillWidth: true

            SectionHeader {
                Layout.fillWidth: true
                text:      "Images"
                collapsed: root._imageCollapsed
                onToggled: root._imageCollapsed = !root._imageCollapsed
            }

            Item {
                Layout.fillWidth: true
                clip: true
                Layout.preferredHeight: !root._imageCollapsed ? _carousel.implicitHeight + 8 : 0
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Carousel {
                    id: _carousel
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                    model:       root.wallpaperProcess ? root.wallpaperProcess.imageFiles : []
                    emptyText:   root.wallpaperProcess && root.wallpaperProcess.wallpaperDir !== ""
                                 ? "No images in dir" : "Dir not set, see Settings"
                    thumbsReady: root.wallpaperProcess ? root.wallpaperProcess.thumbsReady : null
                    thumbPath:   root.wallpaperProcess ? root.wallpaperProcess.thumbPath : null
                    onActivated: (index) => {
                        if (root.wallpaperProcess)
                            root.wallpaperProcess.setImage(root.wallpaperProcess.imageFiles[index].path)
                    }
                    onVisibleChanged: if (visible) currentIndex = root._findImageIdx()
                }
            }
        }

        Connections {
            target: root.wallpaperProcess
            function onImageFilesChanged() {
                if (root._tab === "image") _carousel.currentIndex = root._findImageIdx()
            }
        }

        // ── Video tab ─────────────────────────────────────────────────────────
        PanelCard {
            visible: root._tab === "video"
            Layout.fillWidth: true

            SectionHeader {
                Layout.fillWidth: true
                text:      "Videos"
                collapsed: root._videoCollapsed
                onToggled: root._videoCollapsed = !root._videoCollapsed
            }

            Item {
                Layout.fillWidth: true
                clip: true
                Layout.preferredHeight: !root._videoCollapsed ? _videoCarousel.implicitHeight + 8 : 0
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Carousel {
                    id: _videoCarousel
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                    model:       root.wallpaperProcess ? root.wallpaperProcess.videoFiles : []
                    emptyText:   root.wallpaperProcess && root.wallpaperProcess.wallpaperDir !== ""
                                 ? "No videos in dir" : "Dir not set, see Settings"
                    thumbsReady: root.wallpaperProcess ? root.wallpaperProcess.thumbsReady : null
                    thumbPath:   root.wallpaperProcess ? root.wallpaperProcess.thumbPath : null
                    onActivated: (index) => {
                        if (root.wallpaperProcess)
                            root.wallpaperProcess.setVideo(root.wallpaperProcess.videoFiles[index].path)
                    }
                    onVisibleChanged: if (visible) currentIndex = root._findVideoIdx()
                }
            }
        }

        Connections {
            target: root.wallpaperProcess
            function onVideoFilesChanged() {
                if (root._tab === "video") _videoCarousel.currentIndex = root._findVideoIdx()
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
