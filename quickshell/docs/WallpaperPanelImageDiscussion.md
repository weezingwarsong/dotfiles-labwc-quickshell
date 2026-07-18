# WallpaperPanel — Image Section Discussion

---

## Phase 1 — How it looks and behaves

The image tab is wrapped in a `PanelCard`. Inside: a collapsible `SectionHeader` labelled "Images", followed by the `Carousel`.

The SectionHeader is collapsible for visual uniformity with other panel modules, even though the tab label already says "Image".

When the carousel has no items to show, it displays a centered text message instead of slides:
- Directory not configured → "Dir not set, see Settings"
- Directory set but no images found → "No images in dir"

The active border (2px accent) on the HERO slot is the Carousel's own responsibility — it always shows on the selected item regardless of whether the active wallpaper is currently an image, color, or video. WallpaperPanel does not suppress it.

---

## Phase 2 — What we need

**Structure change in WallpaperPanel.qml**

Replace the current bare `Item` (_imageTab) with:

```
PanelCard                          ← owns all padding, do not add manual margins inside
  ColumnLayout (default alias)
    SectionHeader
      text:      "Images"
      collapsed: _imageCollapsed
      onToggled: _imageCollapsed = !_imageCollapsed

    Item (collapse wrapper)
      Layout.fillWidth: true       ← parent is PanelCard's inner ColumnLayout, this is valid
      clip: true
      Layout.preferredHeight: !_imageCollapsed ? _carousel.implicitHeight : 0
      Behavior on Layout.preferredHeight { NumberAnimation }

      Carousel
        id: _carousel
        anchors.left:  parent.left
        anchors.right: parent.right
        model:     wallpaperProcess ? wallpaperProcess.imageFiles : []
        emptyText: wallpaperProcess && wallpaperProcess.wallpaperDir !== ""
                   ? "No images in dir" : "Dir not set, see Settings"
        onActivated: (index) => {
            if (wallpaperProcess)
                wallpaperProcess.setImage(wallpaperProcess.imageFiles[index].path)
        }
```

**New property on WallpaperPanel**

```
property bool _imageCollapsed: false
```

**Snap-to-active on tab switch**

`currentIndex` on Carousel is a plain writable `property int`. WallpaperPanel sets it imperatively — never as a declarative binding, since Carousel writes to it internally on each scroll step.

Two places WallpaperPanel must snap the carousel:

```qml
// 1. When the image tab becomes visible
onVisibleChanged: if (visible) _carousel.currentIndex = _findImageIdx()

// 2. When imageFiles populates (scan is async — may finish after tab opens)
Connections {
    target: wallpaperProcess
    function onImageFilesChanged() {
        if (root._tab === "image") _carousel.currentIndex = _findImageIdx()
    }
}
```

No animation on snap — no `_animEnabled` guard needed for this iteration.

**Persistence**

`wallpaperProcess.currentPath` is initialized from `Prefs.wallpaperPath` on startup — it survives restart. `wallpaperProcess.imageFiles` is repopulated by `scanDirectory()` in `Component.onCompleted` (if `wallpaperDir` is set). On first open after restart, `_findImageIdx()` matches `currentPath` against the freshly scanned `imageFiles` and returns the correct index.

`_findImageIdx()` already exists in WallpaperPanel.qml — no changes needed there.

**Scanning and filtering — WallpaperProcess's responsibility**

WallpaperPanel does not scan or filter files. `wallpaperProcess.imageFiles` arrives already filtered (by extension), sorted (by name), and capped (200 items). WallpaperPanel passes it directly to Carousel. Neither WallpaperPanel nor Carousel touches the file system.

**New properties on Carousel (additions from WallpaperPanel needs)**

```
property int    currentIndex: 0
property string emptyText:    ""   ← centered text shown when model is empty
```

---

## Phase 3 — How to implement

Replace the current `_imageTab` Item block (lines ~174–315 in WallpaperPanel.qml) with:

```qml
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
            model:     root.wallpaperProcess ? root.wallpaperProcess.imageFiles : []
            emptyText: root.wallpaperProcess && root.wallpaperProcess.wallpaperDir !== ""
                       ? "No images in dir" : "Dir not set, see Settings"
            onActivated: (index) => {
                if (root.wallpaperProcess)
                    root.wallpaperProcess.setImage(root.wallpaperProcess.imageFiles[index].path)
            }
            onVisibleChanged: if (visible) currentIndex = root._findImageIdx()
        }
    }
}
```

Add to WallpaperPanel root properties:
```qml
property bool _imageCollapsed: false
```

Add a `Connections` block to re-snap when scan completes while panel is open:
```qml
Connections {
    target: root.wallpaperProcess
    function onImageFilesChanged() {
        if (root._tab === "image") _carousel.currentIndex = root._findImageIdx()
    }
}
```

The existing `_findImageIdx()` function and `_videoTab` block are unchanged.

**What to remove**

- The entire `Item { id: _imageTab … }` block (image carousel)
- The `Layout.preferredHeight: _heroH + 4 + Style.fontSizeSubtle` sizing — Carousel provides its own `implicitHeight`
- `_ready`, `_animEnabled`, `_scrollPos` — no longer needed for image tab
