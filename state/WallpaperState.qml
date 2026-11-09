// WallpaperState.qml — Fondos de pantalla, swaybg
// Service provider: la UI consume estas propiedades y llama funciones.
// La persistencia la maneja SettingsState (FileView + saveTimer).
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {

    property string wallpaper:      ""
    property string wallpaperDir:   Quickshell.env("HOME") + "/Imágenes/wallpaper"
    property string matugenSchemeType: "scheme-tonal-spot"

    // ── Estado de UI ─────────────────────────────────────────────
    property var    wallpaperList:    []
    property var    thumbCache:       ({})
    property bool   _wpLoaded:        false

    readonly property string _scripts: Qt.resolvedUrl("../scripts/").toString().replace("file://", "")
    readonly property string _thumbCacheFile: Quickshell.env("HOME") + "/.cache/labwc-b/thumbcache.json"

    // ── Exposición de procesos hijos ─────────────────────────────
    property alias wallpaperRestoreProc: wallpaperRestoreProc
    property alias wallpaperProc:        wallpaperProc
    property alias wallpapersProc:       wallpapersProc
    property alias thumbProc:            thumbProc

    // ── Restaurar wallpaper al inicio ──────────────────────────────
    Process {
        id: wallpaperRestoreProc
        property string _cmd: "true"
        command: ["sh", "-c", _cmd]
        running: false
        function restore(path) {
            _cmd = "pkill swaybg 2>/dev/null; swaybg -i '" + path.replace(/'/g, "'\\''") + "' -m fill >/dev/null 2>&1 &"
            running = true
        }
    }

    // ── Proceso unificado de wallpaper — swaybg + matugen ────────────
    Process {
        id: wallpaperProc
        property string _cmd: "true"
        command: ["sh", "-c", wallpaperProc._cmd]
        running: false
        function apply(path) {
            var esc = path.replace(/'/g, "'\\''")
            var matugenCmd = ""
            if (ThemeState.colorTheme === "matugen") {
                var script = Qt.resolvedUrl("../scripts/matugen-apply").toString().replace("file://", "")
                var themeMode = TaskbarState.darkMode ? "dark" : "light"
                matugenCmd = "'" + script + "' '" + esc + "' --type " + WallpaperState.matugenSchemeType + " --mode " + themeMode + " & "
            }
            _cmd = matugenCmd + "pkill swaybg 2>/dev/null; swaybg -i '" + esc + "' -m fill >/dev/null 2>&1 &"
            running = true
            WallpaperState.wallpaper     = path
            SettingsState.markDirty()
        }
    }

    // ── Escanear directorios ─────────────────────────────────────
    Process {
        id: wallpapersProc
        property string _cmd: "true"
        command: ["sh", "-c", wallpapersProc._cmd]
        running: false
        property string _buf: ""
        stdout: SplitParser { onRead: (line) => { wallpapersProc._buf += line } }
        onRunningChanged: {
            if (!running && _buf !== "") {
                try {
                    WallpaperState.wallpaperList = JSON.parse(_buf)
                } catch(e) {}
                _buf = ""
            }
        }
        function load(dir) {
            _buf = ""
            var escaped = "'" + dir.replace(/'/g, "'\\''") + "'"
            _cmd = "'" + WallpaperState._scripts + "wp-helper' scan " + escaped
            running = true
        }
    }

    // ── Generación de thumbnails ──────────────────────────────────
    Process {
        id: thumbProc
        property string _pendingPath: ""
        property string _cmd: "true"
        command: ["sh", "-c", thumbProc._cmd]
        running: false
        property bool _hasOutput: false
        stdout: SplitParser {
            onRead: (line) => {
                var thumbPath = line.trim()
                if (!thumbPath || !thumbProc._pendingPath) return
                var cache = Object.assign({}, WallpaperState.thumbCache)
                cache[thumbProc._pendingPath] = "file://" + encodeURI(thumbPath).replace(/#/g, "%23")
                // LRU acotado: sin esto la copia por thumb es O(n²).
                var keys = Object.keys(cache)
                if (keys.length > 200) {
                    var fresh = {}
                    for (var i = keys.length - 200; i < keys.length; i++) fresh[keys[i]] = cache[keys[i]]
                    cache = fresh
                }
                WallpaperState.thumbCache = cache
                thumbProc._pendingPath = ""
                thumbProc._processQueue()
            }
        }
        property var _queue: []
        function requestThumb(path) {
            if (WallpaperState.thumbCache[path] || _queue.indexOf(path) >= 0) return
            _queue.push(path)
            if (!running) _processQueue()
        }
        function _processQueue() {
            if (_queue.length === 0) return
            var path = _queue.shift()
            _pendingPath = path
            _cmd = "'" + WallpaperState._scripts + "wp-helper' thumb '" + path.replace(/'/g, "'\\''") + "'"
            running = true
        }
    }

    Process {
        id: dirCheckProc
        property string _dir: ""
        property string _cmd: "true"
        command: ["sh", "-c", dirCheckProc._cmd]
        running: false
        onRunningChanged: {
            if (!running && exitCode === 0) {
                WallpaperState.wallpaperList = []
                WallpaperState.wallpaperDir = dirCheckProc._dir
                SettingsState.markDirty()
                WallpaperState._wpLoaded = false
                if (dirCheckProc._dir !== "") WallpaperState.wallpapersProc.load(dirCheckProc._dir)
            }
        }
    }


    Timer {
        id: thumbCacheSaveTimer
        interval: 1000; repeat: false
        onTriggered: {
            var json = JSON.stringify(WallpaperState.thumbCache)
            thumbCacheSaveProc._json = json
            thumbCacheSaveProc.running = true
        }
    }

    Process {
        id: thumbCacheSaveProc
        property string _json: "{}"
        property string _cmd: "true"
        command: ["sh", "-c", thumbCacheSaveProc._cmd]
        running: false
        onRunningChanged: {
            if (running) {
                var dir = Quickshell.env("HOME") + "/.cache/labwc-b"
                _cmd = "mkdir -p '" + dir + "' && printf '%s' '" + _json.replace(/'/g, "'\\''") + "' > '" + dir + "/thumbcache.json'"
            }
        }
    }

    onThumbCacheChanged: thumbCacheSaveTimer.restart()

    // ── Helpers ──────────────────────────────────────────────────

    readonly property var schemeTypes: [
        { id: "scheme-tonal-spot",    label: "Tonal Spot"    },
        { id: "scheme-content",       label: "Content"       },
        { id: "scheme-expressive",    label: "Expressive"    },
        { id: "scheme-fidelity",      label: "Fidelity"      },
        { id: "scheme-fruit-salad",   label: "Fruit Salad"   },
        { id: "scheme-monochrome",    label: "Monochrome"    },
        { id: "scheme-neutral",       label: "Neutral"       },
        { id: "scheme-rainbow",       label: "Rainbow"       },
        { id: "scheme-vibrant",       label: "Vibrant"       },
    ]

    function schemeTypeIndex(id) {
        for (var i = 0; i < WallpaperState.schemeTypes.length; i++)
            if (WallpaperState.schemeTypes[i].id === id) return i
        return 0
    }

    function thumbSource(path) {
        if (!WallpaperState.thumbCache[path] && path !== "")
            thumbProc.requestThumb(path)
        return WallpaperState.thumbCache[path] || ""
    }

    function saveDir(dir) {
        var clean = (dir || "").trim()
        if (clean === "") { wallpaperList = []; wallpaperDir = ""; SettingsState.markDirty(); _wpLoaded = false; return }
        dirCheckProc._dir = clean
        dirCheckProc._cmd = "test -d '" + clean.replace(/'/g, "'\\''") + "'"
        dirCheckProc.running = true
    }


    Timer {
        id: thumbCacheLoadTimer
        interval: 50; repeat: false
        running: true
        onTriggered: thumbCacheLoadProc.running = true
    }

    Process {
        id: thumbCacheLoadProc
        property string _buf: ""
        command: ["sh", "-c", "cat '" + Quickshell.env("HOME") + "/.cache/labwc-b/thumbcache.json' 2>/dev/null"]
        running: false
        stdout: SplitParser { onRead: (line) => { thumbCacheLoadProc._buf += line } }
        onRunningChanged: {
            if (!running && _buf !== "") {
                try { WallpaperState.thumbCache = JSON.parse(_buf) } catch(e) {}
                _buf = ""
            }
        }
    }

}
