import QtQuick
import QtCore
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
    property var imageFiles: []   // [{path, name}]  — images only, capped at 200
    property var videoFiles: []   // [{path, name}]  — video only,  capped at 200

    // ── Slideshow ─────────────────────────────────────────────────────────────
    property bool slideshow:      false
    property var  slideshowFiles: []   // ordered list of paths the user selected
    property int  _slideshowIdx:  0

    // ── Thumbnail cache ───────────────────────────────────────────────────────
    property string _cacheDir:            ""
    property var    thumbsReady:          ({})  // videoPath → true; reassigned each update
    property var    _thumbQueue:          []
    property int    _thumbQueueIdx:       0
    property string _thumbActivePath:     ""
    property string _pendingVideoExtract: ""    // path to extract colors from once thumb ready

    function thumbPath(videoPath) {
        return root._cacheDir + "/" + videoPath.split("/").pop() + ".jpg"
    }

    function _startThumbQueue(videoFiles) {
        root._thumbQueue    = videoFiles.map(function(v) { return v.path })
        root._thumbQueueIdx = 0
        _startNextThumb()
    }

    function _startNextThumb() {
        if (_thumbProc.running) return
        if (_thumbQueueIdx >= _thumbQueue.length) return
        root._thumbActivePath = _thumbQueue[_thumbQueueIdx]
        _thumbProc.running = true
    }

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
        _maybeExtract(path)
    }

    function setVideo(path) {
        root.sourceType  = "video"
        root.currentPath = path
        root.slideshow   = false
        root.lastError   = ""
        Prefs.setWallpaperSourceType("video")
        Prefs.setWallpaperPath(path)
        // Color extraction uses the video thumbnail (first frame via ffmpeg)
        if (Prefs.extractColors) {
            if (root.thumbsReady[path]) {
                _maybeExtract(root.thumbPath(path))
            } else {
                root._pendingVideoExtract = path
            }
        }
    }

    function setColor(color) {
        root.sourceType   = "color"
        root.currentColor = color
        root.slideshow    = false
        root.lastError    = ""
        Prefs.setWallpaperSourceType("color")
        Prefs.setWallpaperColor(color)
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
    }

    function scanDirectory(dir) {
        if (dir === "" || _scanImgProc.running || _scanVidProc.running) return
        // Only clear lists when switching to a different directory — avoids grid flash on rescan
        if (dir !== root.wallpaperDir) {
            root.imageFiles = []
            root.videoFiles = []
        }
        Prefs.setWallpaperDir(dir)
        root.wallpaperDir    = dir
        _scanImgProc.running = true
        _scanVidProc.running = true
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    property string _extractPath: ""
    property string _stateDir:    ""

    function _maybeExtract(path) {
        if (!Prefs.extractColors || path === "") return
        root._extractPath = path
        if (matugenProc.running) return
        matugenProc.running = true
    }

    // Image scan — GIFs capped at 50 MB (AnimatedImage decodes on CPU; huge GIFs are expensive).
    // Static images have no size cap. Results capped at 200 items to keep the Repeater fast.
    Process {
        id: _scanImgProc
        command: ["find", root.wallpaperDir, "-maxdepth", "1", "-type", "f",
                  "-not", "(", "-iname", "*.gif", "-size", "+50M", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                var exts = [".jpg", ".jpeg", ".png", ".webp", ".avif", ".gif"]
                var imgs = []
                text.split("\n").forEach(function(p) {
                    if (imgs.length >= 200) return
                    p = p.trim()
                    if (p === "") return
                    var lower = p.toLowerCase()
                    if (exts.some(function(e) { return lower.endsWith(e) }))
                        imgs.push({ path: p, name: p.split("/").pop() })
                })
                imgs.sort(function(a, b) { return a.name.localeCompare(b.name) })
                root.imageFiles = imgs
                console.log("[WallpaperProcess] images:", imgs.length, "in", root.wallpaperDir)
            }
        }
        onExited: function(code, signal) {
            if (code !== 0)
                console.log("[WallpaperProcess] image scan failed, code", code,
                    "— check directory:", root.wallpaperDir)
        }
    }

    // Video scan — hard cap at 100 MB per file. Wallpaper loops are almost always
    // under 50 MB; feature films are 20–50 GB. The 100 MB line is defensible.
    // Results also capped at 200 items.
    Process {
        id: _scanVidProc
        command: ["find", root.wallpaperDir, "-maxdepth", "1", "-type", "f", "-size", "-100M"]
        stdout: StdioCollector {
            onStreamFinished: {
                var exts = [".mp4", ".webm", ".mkv", ".mov"]
                var vids = []
                text.split("\n").forEach(function(p) {
                    if (vids.length >= 200) return
                    p = p.trim()
                    if (p === "") return
                    var lower = p.toLowerCase()
                    if (exts.some(function(e) { return lower.endsWith(e) }))
                        vids.push({ path: p, name: p.split("/").pop() })
                })
                vids.sort(function(a, b) { return a.name.localeCompare(b.name) })
                root.videoFiles = vids
                console.log("[WallpaperProcess] videos:", vids.length, "in", root.wallpaperDir)
                _startThumbQueue(vids)
            }
        }
        onExited: function(code, signal) {
            if (code !== 0)
                console.log("[WallpaperProcess] video scan failed, code", code,
                    "— check directory:", root.wallpaperDir)
        }
    }

    // Thumbnail extraction — ffmpeg pulls the first keyframe at t=1s for each video.
    // Input seek (-ss before -i) is fast: seeks in the container before decoding.
    // Queue processes one file at a time; onExited kicks off the next.
    Process {
        id: _mkdirProc
        command: ["mkdir", "-p", root._cacheDir]
    }

    Process {
        id: _thumbProc
        command: ["ffmpeg", "-y", "-loglevel", "quiet",
                  "-ss", "00:00:01", "-i", root._thumbActivePath,
                  "-frames:v", "1", "-q:v", "3",
                  root.thumbPath(root._thumbActivePath)]
        onExited: function(code, signal) {
            if (code === 0 && root._thumbActivePath !== "") {
                var updated = Object.assign({}, root.thumbsReady)
                updated[root._thumbActivePath] = true
                root.thumbsReady = updated
                if (root._pendingVideoExtract === root._thumbActivePath) {
                    root._maybeExtract(root.thumbPath(root._thumbActivePath))
                    root._pendingVideoExtract = ""
                }
                console.log("[WallpaperProcess] thumb:", root._thumbActivePath.split("/").pop())
            }
            root._thumbQueueIdx++
            root._startNextThumb()
        }
    }

    // matugen generates colors.json via ~/.config/matugen/config.toml templates.
    // Colors.qml watches that file live and updates Style.qml bindings automatically.
    // For videos, _extractPath points to the cached thumbnail JPEG.
    Process {
        id: _mkdirStateProc
        command: ["mkdir", "-p", root._stateDir]
    }

    Process {
        id: matugenProc
        command: ["matugen", "image", "--source-color-index", "0", root._extractPath]
        onExited: function(code, signal) {
            if (code !== 0)
                console.log("[WallpaperProcess] matugen exited", code, "— is matugen installed?")
            else {
                console.log("[WallpaperProcess] palette extracted from", root._extractPath)
                _readColorsProc.running = true
            }
        }
    }

    Process {
        id: _readColorsProc
        command: ["cat", root._stateDir + "/colors.json"]
        stdout: StdioCollector {
            onStreamFinished: Colors.apply(text)
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
        var home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
                       .toString().replace(/^file:\/\//, "")
        root._cacheDir = home + "/.cache/pillbox/thumbs"
        root._stateDir = home + "/.local/state/quickshell/generated"
        _mkdirProc.running = true
        _mkdirStateProc.running = true
        console.log("[WallpaperProcess] started | sourceType:", root.sourceType,
            "| dir:", root.wallpaperDir, "| thumbCache:", root._cacheDir)
        if (root.wallpaperDir !== "")
            scanDirectory(root.wallpaperDir)
    }
}
