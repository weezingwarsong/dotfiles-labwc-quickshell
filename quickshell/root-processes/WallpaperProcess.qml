import QtQuick
import Quickshell.Io

Item {
    id: root

    // ── State (persisted via Prefs) ───────────────────────────────────────────
    property string sourceType:        Prefs.wallpaperSourceType  // "color"|"image"|"video"
    property string currentPath:       Prefs.wallpaperPath
    property string currentColor:      Prefs.wallpaperColor
    property string wallpaperDir:      Prefs.wallpaperDir
    property int    slideshowInterval: Prefs.slideshowInterval    // seconds

    // ── Directory scan results ────────────────────────────────────────────────
    property var imageFiles: []   // [{path, name}]  — images only
    property var videoFiles: []   // [{path, name}]  — video + gif

    // ── Slideshow ─────────────────────────────────────────────────────────────
    property bool slideshow:      false
    property var  slideshowFiles: []   // ordered list of paths the user selected
    property int  _slideshowIdx:  0

    // ── Error ─────────────────────────────────────────────────────────────────
    property string lastError: ""

    // ── Public API ────────────────────────────────────────────────────────────

    function setImage(path) {
        root.sourceType  = "image"
        root.currentPath = path
        root.slideshow   = false
        root.lastError   = ""
        Prefs.setWallpaperSourceType("image")
        Prefs.setWallpaperPath(path)
        _applyYin(path)
    }

    function setVideo(path) {
        root.sourceType  = "video"
        root.currentPath = path
        root.slideshow   = false
        root.lastError   = ""
        Prefs.setWallpaperSourceType("video")
        Prefs.setWallpaperPath(path)
        _applyYin(path)
    }

    function setColor(color) {
        root.sourceType   = "color"
        root.currentColor = color
        root.slideshow    = false
        root.lastError    = ""
        Prefs.setWallpaperSourceType("color")
        Prefs.setWallpaperColor(color)
        // No yin call — the color background window in shell.qml handles rendering.
    }

    function startSlideshow(files) {
        if (files.length === 0) return
        root.slideshow      = true
        root.slideshowFiles = files
        root._slideshowIdx  = 0
        root.sourceType     = "image"
        root.currentPath    = files[0]
        root.lastError      = ""
        Prefs.setWallpaperSourceType("image")
        Prefs.setWallpaperPath(files[0])
        _applyYin(files[0])
    }

    function stopSlideshow() {
        root.slideshow = false
    }

    function setSlideshowInterval(secs) {
        root.slideshowInterval = secs
        Prefs.setSlideshowInterval(secs)
    }

    function nextSlide() {
        if (root.slideshowFiles.length === 0) return
        root._slideshowIdx = (root._slideshowIdx + 1) % root.slideshowFiles.length
        var path = root.slideshowFiles[root._slideshowIdx]
        root.currentPath = path
        Prefs.setWallpaperPath(path)
        _applyYin(path)
    }

    function scanDirectory(dir) {
        if (dir === "" || scanProc.running) return
        Prefs.setWallpaperDir(dir)
        root.wallpaperDir = dir
        scanProc.running = true
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    property string _pendingYinPath: ""

    function _applyYin(path) {
        root._pendingYinPath = path
        if (yinProc.running) return
        yinProc.running = true
    }

    Process {
        id: yinProc
        command: ["yinctl", "--img", root._pendingYinPath]
        onExited: function(code, signal) {
            if (code !== 0) {
                root.lastError = "yin not started"
                console.log("[WallpaperProcess] yinctl exited", code, "— is yin running?")
            } else {
                root.lastError = ""
            }
        }
    }

    Process {
        id: scanProc
        command: ["find", root.wallpaperDir, "-maxdepth", "1", "-type", "f"]
        stdout: StdioCollector {
            onStreamFinished: {
                var imageExts = [".jpg", ".jpeg", ".png", ".webp", ".avif"]
                var videoExts = [".mp4", ".webm", ".mkv", ".mov", ".gif"]
                var imgs = [], vids = []
                text.split("\n").forEach(function(p) {
                    p = p.trim()
                    if (p === "") return
                    var lower = p.toLowerCase()
                    var name  = p.split("/").pop()
                    if (imageExts.some(function(e) { return lower.endsWith(e) }))
                        imgs.push({ path: p, name: name })
                    else if (videoExts.some(function(e) { return lower.endsWith(e) }))
                        vids.push({ path: p, name: name })
                })
                imgs.sort(function(a, b) { return a.name.localeCompare(b.name) })
                vids.sort(function(a, b) { return a.name.localeCompare(b.name) })
                root.imageFiles = imgs
                root.videoFiles = vids
                console.log("[WallpaperProcess] scan:", imgs.length, "images,",
                    vids.length, "videos in", root.wallpaperDir)
            }
        }
        onExited: function(code, signal) {
            if (code !== 0)
                console.log("[WallpaperProcess] scan failed, code", code,
                    "— check that the directory exists:", root.wallpaperDir)
        }
    }

    Timer {
        id: slideshowTimer
        interval: root.slideshowInterval * 1000
        repeat:   true
        running:  root.slideshow && root.slideshowFiles.length > 1
        onTriggered: root.nextSlide()
    }

    Component.onCompleted: {
        console.log("[WallpaperProcess] started | sourceType:", root.sourceType,
            "| dir:", root.wallpaperDir)
        // Restore last wallpaper on startup
        if ((root.sourceType === "image" || root.sourceType === "video")
                && root.currentPath !== "")
            _applyYin(root.currentPath)
        // Populate file grids if a directory was previously set
        if (root.wallpaperDir !== "")
            scanProc.running = true
    }
}
