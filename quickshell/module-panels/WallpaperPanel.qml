import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

Item {
    id: root

    property var    wallpaperProcess: null
    property string activePanel:      ""
    signal navigateRequested(int direction)

    implicitHeight: _col.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius:       Style.radLg
        color:        Style.panelBgColor
        border.color: Style.panelBorderColor
        border.width: 1
        clip:         true
    }

    // ── Tile geometry (3 tiles visible, 4px gap) ──────────────────────────────
    readonly property int _spacing: 4
    readonly property int _tileW:   Math.floor((width - 24 - _spacing * 2) / 3)
    readonly property int _imgH:    Math.round(_tileW * 0.6)
    readonly property int _lblH:    18
    readonly property int _tileH:   _imgH + _lblH + _spacing

    // ── Tabs ──────────────────────────────────────────────────────────────────
    property string _tab: "color"

    // ── Slideshow selection (image tab) ───────────────────────────────────────
    property bool _slideshowMode: false
    property var  _selectedPaths: []   // paths ticked for slideshow

    function _toggleSelection(path) {
        var arr = root._selectedPaths.slice()
        var idx = arr.indexOf(path)
        if (idx === -1) arr.push(path)
        else            arr.splice(idx, 1)
        root._selectedPaths = arr
    }

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

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 10

        PanelNavBar { activePanel: root.activePanel; onNavigateRequested: (dir) => root.navigateRequested(dir) }

        // Tab bar
        TogglePair {
            Layout.fillWidth: true
            labelA: "Color"
            labelB: "Media"
            selected: root._tab === "media" ? 1 : 0
            onToggled: (i) => root._tab = (i === 0 ? "color" : "media")
        }

        // ── Color tab ─────────────────────────────────────────────────────────
        ColumnLayout {
            visible: root._tab === "color"
            Layout.fillWidth: true
            spacing: 8

            SectionLabel { text: "Background Color" }

            Grid {
                columns: 6
                spacing: root._spacing
                Layout.fillWidth: true

                Repeater {
                    model: root._swatches
                    Rectangle {
                        required property var modelData
                        width:  Math.floor((root.width - 24 - 5 * root._spacing) / 6)
                        height: width
                        radius: Style.radSm
                        color:  modelData.hex

                        readonly property bool _active:
                            root.wallpaperProcess
                            && root.wallpaperProcess.sourceType === "color"
                            && root.wallpaperProcess.currentColor === modelData.hex

                        border.width: _active ? 2 : 1
                        border.color: _active ? Style.accentColor : Style.borderFaintColor

                        HoverHandler { id: _swatchHover }
                        QQC.ToolTip {
                            visible: _swatchHover.hovered
                            text:    modelData.name
                            delay:   400
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: if (root.wallpaperProcess) root.wallpaperProcess.setColor(modelData.hex)
                        }
                    }
                }
            }

            // Error feedback
            Text {
                visible: root.wallpaperProcess && root.wallpaperProcess.lastError !== ""
                         && root.wallpaperProcess.sourceType === "color"
                text:    root.wallpaperProcess ? root.wallpaperProcess.lastError : ""
                color:   Style.textCritical
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeSubtle
            }
        }

        // ── Media tab ─────────────────────────────────────────────────────────
        ColumnLayout {
            visible: root._tab === "media"
            Layout.fillWidth: true
            spacing: 8

            // Directory input
            SectionLabel { text: "Directory" }
            RowLayout {
                Layout.fillWidth: true
                spacing: root._spacing

                Rectangle {
                    Layout.fillWidth: true
                    height: Style.buttonHeight
                    radius: Style.radSm
                    color:  Style.surfaceMidColor
                    border.width: Style.elementBorderWidth
                    border.color: Style.borderSoftColor

                    TextInput {
                        id: _dirInput
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 6 }
                        text:            root.wallpaperProcess ? root.wallpaperProcess.wallpaperDir : ""
                        color:           Style.textSecondary
                        font.family:     Style.fontMono
                        font.pixelSize:  Style.fontSizeBody
                        clip:            true
                        selectByMouse:   true
                        onAccepted: if (root.wallpaperProcess) root.wallpaperProcess.scanDirectory(text)

                        Text {
                            anchors.fill:    parent
                            text:            "~/Pictures/wallpapers"
                            color:           Style.textFaint
                            font.family:     Style.fontMono
                            font.pixelSize:  Style.fontSizeBody
                            visible:         _dirInput.text === ""
                        }
                    }
                }

                PanelButton {
                    label: "Scan"
                    onClicked: if (root.wallpaperProcess) root.wallpaperProcess.scanDirectory(_dirInput.text)
                }
            }

            PanelDivider {}

            // ── Images section ────────────────────────────────────────────────
            SectionLabel { text: "Images" }

            RowLayout {
                Layout.fillWidth: true
                spacing: root._spacing

                TogglePair {
                    Layout.fillWidth: true
                    labelA: "Single"
                    labelB: "Slideshow"
                    selected: root._slideshowMode ? 1 : 0
                    onToggled: (i) => {
                        root._slideshowMode = (i === 1)
                        root._selectedPaths = []
                        if (!root._slideshowMode && root.wallpaperProcess)
                            root.wallpaperProcess.stopSlideshow()
                    }
                }
            }

            // Slideshow controls (interval + apply)
            RowLayout {
                visible: root._slideshowMode
                Layout.fillWidth: true
                spacing: root._spacing

                Text {
                    text:           "Every"
                    color:          Style.textSecondary
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                }

                PanelButton {
                    label: "–"
                    onClicked: {
                        if (!root.wallpaperProcess) return
                        var v = Math.max(5, root.wallpaperProcess.slideshowInterval - 5)
                        root.wallpaperProcess.setSlideshowInterval(v)
                    }
                }

                Text {
                    text: root.wallpaperProcess
                        ? (root.wallpaperProcess.slideshowInterval >= 60
                            ? Math.floor(root.wallpaperProcess.slideshowInterval / 60) + "m"
                            : root.wallpaperProcess.slideshowInterval + "s")
                        : "—"
                    color:          Style.textPrimary
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                    horizontalAlignment: Text.AlignHCenter
                    Layout.minimumWidth: 32
                }

                PanelButton {
                    label: "+"
                    onClicked: {
                        if (!root.wallpaperProcess) return
                        root.wallpaperProcess.setSlideshowInterval(
                            root.wallpaperProcess.slideshowInterval + 5)
                    }
                }

                Item { Layout.fillWidth: true }

                PanelButton {
                    label:   "Apply"
                    variant: "accent"
                    onClicked: {
                        if (!root.wallpaperProcess) return
                        if (root._selectedPaths.length > 0)
                            root.wallpaperProcess.startSlideshow(root._selectedPaths.slice())
                        else
                            root.wallpaperProcess.startSlideshow(
                                root.wallpaperProcess.imageFiles.map(function(f) { return f.path }))
                    }
                }
            }

            // Image grid
            Item {
                Layout.fillWidth: true
                implicitHeight: root.wallpaperProcess && root.wallpaperProcess.imageFiles.length > 0
                    ? 3 * root._tileH + 2 * root._spacing
                    : _emptyImg.implicitHeight + 8
                clip: true

                // Empty state
                Text {
                    id: _emptyImg
                    visible: !root.wallpaperProcess || root.wallpaperProcess.imageFiles.length === 0
                    anchors.centerIn: parent
                    text:  root.wallpaperProcess && root.wallpaperProcess.wallpaperDir !== ""
                        ? "No images found"
                        : "Set a directory above"
                    color:          Style.textMuted
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                }

                Flickable {
                    visible: root.wallpaperProcess && root.wallpaperProcess.imageFiles.length > 0
                    anchors.fill: parent
                    flickableDirection: Flickable.VerticalFlick
                    contentWidth:  width
                    contentHeight: _imgGrid.height
                    clip: true

                    Grid {
                        id: _imgGrid
                        columns: 3
                        flow:    Grid.LeftToRight
                        spacing: root._spacing

                        Repeater {
                            model: root.wallpaperProcess ? root.wallpaperProcess.imageFiles : []
                            delegate: _imageTileDelegate
                        }
                    }
                }
            }

            PanelDivider {}

            // ── Video section ─────────────────────────────────────────────────
            SectionLabel { text: "Videos" }

            Item {
                Layout.fillWidth: true
                implicitHeight: root.wallpaperProcess && root.wallpaperProcess.videoFiles.length > 0
                    ? 3 * root._tileH + 2 * root._spacing
                    : _emptyVid.implicitHeight + 8
                clip: true

                Text {
                    id: _emptyVid
                    visible: !root.wallpaperProcess || root.wallpaperProcess.videoFiles.length === 0
                    anchors.centerIn: parent
                    text:  root.wallpaperProcess && root.wallpaperProcess.wallpaperDir !== ""
                        ? "No videos found"
                        : "Set a directory above"
                    color:          Style.textMuted
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                }

                Flickable {
                    visible: root.wallpaperProcess && root.wallpaperProcess.videoFiles.length > 0
                    anchors.fill: parent
                    flickableDirection: Flickable.VerticalFlick
                    contentWidth:  width
                    contentHeight: _vidGrid.height
                    clip: true

                    Grid {
                        id: _vidGrid
                        columns: 3
                        flow:    Grid.LeftToRight
                        spacing: root._spacing

                        Repeater {
                            model: root.wallpaperProcess ? root.wallpaperProcess.videoFiles : []
                            delegate: _videoTileDelegate
                        }
                    }
                }
            }

            // Error feedback
            Text {
                visible: root.wallpaperProcess && root.wallpaperProcess.lastError !== ""
                         && root.wallpaperProcess.sourceType !== "color"
                text:    root.wallpaperProcess ? root.wallpaperProcess.lastError : ""
                color:   Style.textCritical
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeSubtle
            }
        }
    }

    // ── Image tile delegate ───────────────────────────────────────────────────
    Component {
        id: _imageTileDelegate

        Item {
            required property var  modelData
            required property int  index
            width:  root._tileW
            height: root._tileH

            readonly property bool _active:
                root.wallpaperProcess
                && root.wallpaperProcess.sourceType === "image"
                && root.wallpaperProcess.currentPath === modelData.path
            readonly property bool _selected:
                root._slideshowMode && root._selectedPaths.indexOf(modelData.path) !== -1

            Rectangle {
                id: _imgBg
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: root._imgH
                radius: Style.radSm
                color:  Style.surfaceMidColor
                border.width: _active ? 2 : 1
                border.color: _active ? Style.accentColor : Style.borderFaintColor
                clip: true

                Image {
                    anchors.fill: parent
                    source:       "file://" + modelData.path
                    fillMode:     Image.PreserveAspectCrop
                    asynchronous: true
                    smooth:       true
                    layer.enabled: true   // clip to parent radius
                }
            }

            Text {
                anchors { left: parent.left; right: parent.right; top: _imgBg.bottom; topMargin: 2 }
                text:           modelData.name
                elide:          Text.ElideRight
                color:          Style.textMuted
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeSubtle
            }

            // Slideshow selection checkmark
            Text {
                visible:        _selected
                anchors { top: _imgBg.top; right: _imgBg.right; margins: 2 }
                text:           String.fromCodePoint(0xf05e0)  // nf-md-checkbox_marked
                font.family:    Style.fontNerd
                font.pixelSize: 12
                color:          Style.accentColor
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked: {
                    if (!root.wallpaperProcess) return
                    if (root._slideshowMode) {
                        root._toggleSelection(modelData.path)
                    } else {
                        root.wallpaperProcess.setImage(modelData.path)
                    }
                }
            }
        }
    }

    // ── Video tile delegate ───────────────────────────────────────────────────
    Component {
        id: _videoTileDelegate

        Item {
            required property var modelData
            required property int index
            width:  root._tileW
            height: root._tileH

            readonly property bool _active:
                root.wallpaperProcess
                && root.wallpaperProcess.sourceType === "video"
                && root.wallpaperProcess.currentPath === modelData.path

            readonly property bool _hasThumb:
                root.wallpaperProcess
                && !!root.wallpaperProcess.thumbsReady[modelData.path]

            Rectangle {
                id: _vidBg
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: root._imgH
                radius: Style.radSm
                color:  Style.surfaceMidColor
                border.width: _active ? 2 : 1
                border.color: _active ? Style.accentColor : Style.borderFaintColor
                clip: true

                Image {
                    anchors.fill: parent
                    visible:      _hasThumb
                    source:       _hasThumb
                                  ? ("file://" + root.wallpaperProcess.thumbPath(modelData.path))
                                  : ""
                    fillMode:     Image.PreserveAspectCrop
                    asynchronous: true
                    smooth:       true
                    layer.enabled: true
                }

                Text {
                    anchors.centerIn: parent
                    visible:        !_hasThumb
                    text:           String.fromCodePoint(0xf040a)  // nf-md-play_box_outline
                    font.family:    Style.fontNerd
                    font.pixelSize: Math.round(root._imgH * 0.45)
                    color:          _active ? Style.accentColor : Style.textMuted
                }
            }

            Text {
                anchors { left: parent.left; right: parent.right; top: _vidBg.bottom; topMargin: 2 }
                text:           modelData.name
                elide:          Text.ElideRight
                color:          Style.textMuted
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeSubtle
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked: if (root.wallpaperProcess) root.wallpaperProcess.setVideo(modelData.path)
            }
        }
    }
}
