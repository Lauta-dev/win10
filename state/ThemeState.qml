// ThemeState.qml — Temas, colores, GTK, iconos, dark mode
// Service provider: la UI consume estas propiedades y llama funciones.
// La persistencia la maneja SettingsState (FileView + saveTimer).
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {

    // ── Apariencia — color y tema ──────────────────────────────────
    property string accentDark:   ""
    property string accentLight:  ""
    property string colorTheme:   "chromeos"
    property bool   darkModePersisted: false
    property bool   _themeLoaded: false

    // ── GTK + Icon theme ──────────────────────────────────────────
    property string gtkTheme:  ""
    property string iconTheme: ""
    property var    iconMap:   ({})

    // ── Available themes (scanned from filesystem) ───────────────
    property var gtkThemes:  []
    property var iconThemes: []

    property alias iconMapProc: iconMapProc

    // ── Icon map — resolve-icons (binario Go) ────────────────────
    function rebuildIconMap(theme) {
        iconMapProc._theme  = theme || ""
        iconMapProc._buf    = ""
        iconMapProc.running = true
    }

    Process {
        id: iconMapProc
        property string _theme: ""
        property string _buf:   ""
        command: {
            var script = Qt.resolvedUrl("../bin/resolve-icons").toString().replace("file://", "")
            return _theme !== ""
                ? [script, "--theme", _theme]
                : [script]
        }
        running: false
        stdout: SplitParser {
            onRead: (line) => { if (line.trim() !== "") iconMapProc._buf += line }
        }
        onRunningChanged: {
            if (running) { _buf = ""; return }
            if (_buf === "") return
            try {
                var newMap  = JSON.parse(_buf)
                var changed = Object.keys(newMap).length !== Object.keys(ThemeState.iconMap).length
                              || iconMapProc._theme !== ""
                if (changed) {
                    ThemeState.iconMap = newMap
                    SettingsState.markDirty()
                }
            } catch(e) {}
            _buf = ""
        }
        function run() { _theme = ""; running = true }
    }

    // ── Scan available GTK themes ─────────────────────────────────
    Process {
        id: gtkThemeScanProc
        property string _buf: ""
        command: ["sh", "-c", "for d in /usr/share/themes ~/.themes; do [ -d \"$d\" ] && ls -1 \"$d\" 2>/dev/null; done | sort -u"]
        running: false
        stdout: SplitParser {
            onRead: (line) => { var t = line.trim(); if (t !== "") gtkThemeScanProc._buf += t + "\n" }
        }
        onRunningChanged: {
            if (running) { _buf = ""; return }
            var lines = _buf.trim().split("\n")
            var result = []
            for (var i = 0; i < lines.length; i++) {
                var t = lines[i].trim()
                if (t !== "") result.push(t)
            }
            gtkThemes = result
        }
    }

    // ── Scan available icon themes ────────────────────────────────
    Process {
        id: iconThemeScanProc
        property string _buf: ""
        command: ["sh", "-c", "for d in /usr/share/icons ~/.local/share/icons ~/.icons; do [ -d \"$d\" ] && ls -1 \"$d\" 2>/dev/null; done | sort -u"]
        running: false
        stdout: SplitParser {
            onRead: (line) => { var t = line.trim(); if (t !== "") iconThemeScanProc._buf += t + "\n" }
        }
        onRunningChanged: {
            if (running) { _buf = ""; return }
            var lines = _buf.trim().split("\n")
            var result = []
            for (var i = 0; i < lines.length; i++) {
                var t = lines[i].trim()
                if (t !== "") result.push(t)
            }
            iconThemes = result
        }
    }

    function scanThemes() {
        gtkThemeScanProc.running = true
        iconThemeScanProc.running = true
    }

    // ── Apply GTK theme (gsettings + settings.ini via gtk-apply) ──
    Process {
        id: gtkThemeApplyProc
        property string _theme: ""
        property string _mode: "dark"
        command: {
            var script = Qt.resolvedUrl("../bin/gtk-apply").toString().replace("file://", "")
            return [script, "--gtk", _theme, "--mode", _mode]
        }
        running: false
        onRunningChanged: {
            if (!running && _theme !== "") {
                ThemeState.gtkTheme = _theme
                SettingsState.markDirty()
            }
        }
    }

    function applyGtkTheme(name) {
        gtkThemeApplyProc._theme = name
        gtkThemeApplyProc._mode = TaskbarState.darkMode ? "dark" : "light"
        gtkThemeApplyProc.running = true
    }

    // ── Apply icon theme (gsettings + settings.ini via gtk-apply) ─
    Process {
        id: iconThemeApplyProc
        property string _theme: ""
        property string _mode: "dark"
        command: {
            var script = Qt.resolvedUrl("../bin/gtk-apply").toString().replace("file://", "")
            return [script, "--icons", _theme, "--mode", _mode]
        }
        running: false
        onRunningChanged: {
            if (!running && _theme !== "") {
                ThemeState.iconTheme = _theme
                ThemeState.rebuildIconMap(_theme)
                SettingsState.markDirty()
            }
        }
    }

    function applyIconTheme(name) {
        iconThemeApplyProc._theme = name
        iconThemeApplyProc._mode = TaskbarState.darkMode ? "dark" : "light"
        iconThemeApplyProc.running = true
    }

    // ── Presets de temas (data/shell-themes.json) ─────────────────
    // Fuente unica del catalogo: el script y la UI leen el mismo JSON.
    property var shellThemes: []
    property bool _shellThemesLoaded: false

    FileView {
        id: shellThemesFile
        path: Qt.resolvedUrl("../data/shell-themes.json").toString().replace("file://", "")
        watchChanges: false
        preload: true
        onLoaded: {
            try {
                var data = JSON.parse(shellThemesFile.text())
                if (data && data.themes) ThemeState.shellThemes = data.themes
            } catch (e) {}
            _shellThemesLoaded = true
        }
    }

    function shellThemeById(id) {
        for (var i = 0; i < shellThemes.length; i++)
            if (shellThemes[i].id === id) return shellThemes[i]
        return null
    }

    Component.onCompleted: {
        if (_shellThemesLoaded) return
        try {
            var data = JSON.parse(shellThemesFile.text())
            if (data && data.themes) shellThemes = data.themes
        } catch (e) {}
    }

    // ── Apply shell theme (md3 dual + GTK/Qt via shell-theme) ──
    Process {
        id: shellThemeApplyProc
        property string _theme: ""
        property string _mode: "dark"
        command: {
            var script = Qt.resolvedUrl("../bin/shell-theme").toString().replace("file://", "")
            return [script, _theme, "--mode", _mode]
        }
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var t = line.trim()
                if (t.indexOf("__GTK_THEME__=") === 0) ThemeState.gtkTheme = t.substring(14)
            }
        }
        onRunningChanged: {
            if (!running && _theme !== "") SettingsState.markDirty()
        }
    }

    // Regeneracion matugen bajo demanda (misma invocacion que el restore).
    Process {
        id: matugenThemeProc
        property string _cmd: ""
        property string _theme: ""
        command: ["sh", "-c", _cmd]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var t = line.trim()
                if (t.indexOf("__GTK_THEME__=") === 0) ThemeState.gtkTheme = t.substring(14)
            }
        }
        onRunningChanged: {
            if (!running && _theme !== "") SettingsState.markDirty()
        }
    }

    function applyShellTheme(id) {
        if (id === "matugen") {
            colorTheme = id
            SettingsState.markDirty()
            if (!WallpaperState.wallpaper) return
            var script = Qt.resolvedUrl("../bin/matugen-apply").toString().replace("file://", "")
            var wp = WallpaperState.wallpaper.replace(/'/g, "'\\''")
            var mode = TaskbarState.darkMode ? "dark" : "light"
            matugenThemeProc._cmd = "'" + script + "' '" + wp + "' --type " + WallpaperState.matugenSchemeType + " --mode " + mode
            matugenThemeProc._theme = id
            matugenThemeProc.running = false
            matugenThemeProc.running = true
            return
        }
        if (!shellThemeById(id)) return
        // Optimista: la UI marca activo ya; el script escribe los JSON
        // (Style recarga por watch) y el GTK coherente.
        colorTheme = id
        SettingsState.markDirty()
        shellThemeApplyProc._theme = id
        shellThemeApplyProc._mode = TaskbarState.darkMode ? "dark" : "light"
        shellThemeApplyProc.running = false
        shellThemeApplyProc.running = true
    }

    // ── Dark mode sync ────────────────────────────────────────────
    Connections {
        target: TaskbarState
        function onDarkModeChanged() {
            if (_themeLoaded) {
                darkModePersisted = TaskbarState.darkMode
                SettingsState.markDirty()
            }
        }
    }
}
